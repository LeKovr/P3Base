use strict;
use warnings;

use Cwd;
use DBI;
use JSON;

use Config::General;
use Template 2;

use Plack::Builder;
use Plack::Request;
use Plack::Middleware::Session;
use Plack::Session::Store::DBI;
use JSON::RPC::Dispatcher;

use lib 'lib';
use P3Base::ProcHash;
use App;

#----------------------------------------------------------------------
# Setup config

my $root = $ENV{'APP_ROOT'} || getcwd;

my $conf = Config::General->new(
      -ConfigFile => $root . '/' . ($ENV{'APP_CONFIG'} || 'app.conf'), 
      -UTF8 => 1, 
      -LowerCaseNames => 0,
      -ExtendedAccess => 1,
      -UseApacheInclude => 1,
      -IncludeRelative => 1
) or die 'Config file error: '.$!;

my %cfg = $conf->hash('APP');

#----------------------------------------------------------------------
# Setup Template Toolkit

my %tt = $conf->hash('TT');
$tt{'INCLUDE_PATH'} ||= $root . ($tt{'INCLUDE_SUFFIX'} || '/tmpl');

#----------------------------------------------------------------------
# Setup Database

my %db = $conf->hash('DB');

my $_db;

my $get_dbh = sub {
  if (!$_db) {
      $_db = DBI->connect($db{'DSN'}, undef, undef, {
        pg_enable_utf8 => 1,
        PrintError => 1,
        RaiseError => 0,
      });
      if($db{'init_sql'}) { $_db->do($db{'init_sql'}) }
  }
  return $_db;
};

#----------------------------------------------------------------------
# Setup ProcFactory
my $pf = App->new(root => $root, config => \%cfg, get_dbh => $get_dbh);

#----------------------------------------------------------------------
# Account purge stamp
my $_expire;

#----------------------------------------------------------------------
builder {

  # purge accounts if the time has come
  enable sub {
    my $app = shift;
    sub {
        my $env = shift;
        if ($cfg{expire_check} and (!$_expire or $_expire < time() - $cfg{expire_check} * 3600)) {
          # time to purge
          $pf->proc_call('account_purge', $cfg{expire_interval});
          $_expire = time();
        }
        $app->($env);
    }
  };  

  # These files can be served directly
  enable 'Static',
      path => qr{\.(gif|png|jpg|swf|ico|mov|mp3|pdf|js|css)$},
      root => $root . '/static';

  # session support with DB storage
  enable 'Session',
    store => Plack::Session::Store::DBI->new(
      get_dbh => $get_dbh,
      # Serialize with JSON for testing & future postgresql internal access
      serializer   => sub { JSON->new->utf8->canonical(1)->encode( $_[0] ) },
      deserializer => sub { JSON->new->decode( $_[0] ) },
      table_name   => 'app.session'
    );

  # RPC calls from javascript
  mount $cfg{rpc_uri} => builder {
    tie my %r, 'P3Base::ProcHash', $pf, 'plack';
    my $rpc = JSON::RPC::Dispatcher->new;
    $rpc->rpcs(\%r);
    $rpc->to_app;    
  };

  # Pages
  mount '/' => builder {
    # pass tt2 vars by reference
    enable sub {
      my $app = shift;
      sub {
        my $env = shift;
        my $session = Plack::Session->new($env);
        tie my %r, 'P3Base::ProcHash', $pf, 'sub', Plack::Request->new($env);
        $env->{'tt.vars'} = {
          meta => {             # shared template hash
            'title' => undef,   # page title
            'top' => [],        # page head includes
            'btm' => [],        # bottom page includes
          },
          session => $session,  # session data
          api => \%r,           # RPC calls from templates
          cfg => {%cfg}         # RO config
        };
        my $ret = $app->($env);

        # check if page result is redirect
        my $redirect = $env->{'tt.vars'}{'meta'}{'redirect'};
        if ($redirect and $redirect ne $env->{REQUEST_URI}) {
          my $res = Plack::Response->new;
          $res->redirect($redirect, 302);
          $ret = $res->finalize;
        }
        $ret;
      }
    };

    # show auth page when restricted page requested and user is anonymous
    enable sub {
      my $app = shift;
      sub {
        my $env = shift;
        my $priv = $cfg{'Private'};
        my $need_auth = (exists($priv->{$env->{'PATH_INFO'}}) and !$env->{'psgix.session'}{'profile'});
        if ($need_auth) {
          $env->{'PATH_INFO'} = $cfg{'auth_uri'};
          $env->{'tt.vars'}{'meta'}{'auth'} = 1;   # set auth flag for templates
        }
        my $ret = $app->($env);
        $ret->[0] = 403 if ($need_auth); # set http status when auth requested
        $ret;
      }
    };     

    # process templates
    enable 'TemplateToolkit',
      tt  => Template->new( %tt ), 
      404 => $cfg{'error_tmpl'},
      request_vars => ['path'],
      content_type => 'text/html; charset=utf-8';
  };    
};

