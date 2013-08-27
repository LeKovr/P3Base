package P3Base::ProcFactory;

use strict;
use warnings;

our $VERSION   = '0.20';

use JSON;
use Plack::Session;

use Data::Dumper;

#----------------------------------------------------------------------
# database handle accessor
sub get_dbh { return shift->{'get_dbh'}}

#----------------------------------------------------------------------
# make object from hash or hashref
sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $self->{'procs'} = $self->_proc_list;
    $self;
}

#----------------------------------------------------------------------
# available procs references
# sub ref for simple call
# hash ref for $env arguments
sub _proc_list {
  {
    # demo procs for RPC testing, see t/rpc.t
    'ping'  => sub { return 'pong' },
  };

}

#----------------------------------------------------------------------
# utility sub - fetch json from database exception
sub _db_error {
  my $self = shift;
  my $msg = shift;
  if ($msg =~ /ERROR\:\s+(\[.+\])$/) {
    JSON->new->decode($1)
  } else {
    [1000, $msg];
  }
}

#----------------------------------------------------------------------
# utility sub - check required args presense
# returns array of hashes with field errors
sub _check_required {
  my ($self, $code, $args, @params) = @_;
  my @ret;
  foreach my $p (@params) {
    push (@ret, { 
      code => $code,
      param => $p,
      message => 'Param does not set'
    }) if (!defined($args->{$p}) or $args->{$p} eq '');
  }
  return @ret;
}

#----------------------------------------------------------------------
# Return procedure call with appropriate format for custom environment
# Supported are:
# plack - JSON::RPC::Dispatcher 
# sub - Template (Template Toolkit 2)
sub proc {
  my ($self, $format, $method, @args) = @_;
  return undef unless ($self->proc_exists($method));
  my $ret;
  if ($format eq 'plack') {
    return {
      with_plack_request => 1,
      function => sub { return $self->proc_call($method, @_) }
    };
  } elsif ($format eq 'sub') {
    return sub { return $self->proc_call($method, $args[0], @_) }
  } else {
    die "Unknown ProcFactory format ($format)";
  }
}

#----------------------------------------------------------------------
# tied hash (ProcHash) support method - check procedure existance
sub proc_exists {
  my $self = shift;
  my $method = shift;
  my $procs = $self->{'procs'};
  return exists($procs->{$method});
}

#----------------------------------------------------------------------
# call sub from $self->{'procs'}
sub proc_call {
  my $self = shift;
  my $method = shift; # sub name
  my $req = shift;    # plack request or tie arg

  my $procs = $self->{'procs'};
  my $ret;
  if (ref($procs->{$method}) eq 'HASH') {
    my $sub = $procs->{$method}{'sub'};
    $ret = $sub->($self, $req, @_);
  } else {
    my $sub = $procs->{$method};
    $ret = $sub->(@_);
  }
  return $ret;
}

#----------------------------------------------------------------------

1;

   __END__

=pod

=head1 NAME

P3Base::ProcFactory - Application logic as procedure list

=head1 SYNOPSIS

  # Setup ProcFactory
  my $pf = App->new(root => $root, config => \%cfg, get_dbh => $get_dbh);


=head2 Use in templates

  [% 
    api.guess(10);
  %]

  [%
  TRY;
    x = api.guess(11); 
    x;
  CATCH;
    # 'ERROR: ' _ error.type;
    USE dumper(indent=1, pad="  "); '<!-- ' _ dumper.dump(error.info) _ ' -->';
  END;
  %]

=head2 Use in javascript

    $('.form-signin').on('submit', function(event) { 
      return $.rpcForm.on('login', event, function(result) { 
        location.reload();
      }); 
    });


=head1 DESCRIPTION

This package aims to be the new age of PGWS framework.

L<https://github.com/LeKovr/pgws>

=head1 AUTHOR

Alexey Kovrizhkin E<lt>lekovr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2013, Alexey Kovrizhkin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

 