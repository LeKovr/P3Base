package App;

# Прикладная логика приложения


use strict;
use warnings;

use base qw(P3Base::ProcFactory);
use Data::Dumper;
#----------------------------------------------------------------------
# перегрузка метода списка функций
sub _proc_list {
  my $self = shift;
  my $procs = $self->SUPER::_proc_list;

  my %proc = (
    %$procs,
    # applied procs
    # ссылка оформляется как хэш - в этом случае вызов получает в аргументах 
    # plack request
    'register'      => { 'sub' => \&register },
    'login'         => { 'sub' => \&login },
    'logout'        => { 'sub' => \&logout },
    'account_purge' => { 'sub' => \&account_purge },
    'session_purge' => { 'sub' => \&session_purge },
  );
  return \%proc;
}

#----------------------------------------------------------------------
# applied sub - register user
# returns 1 on success
sub register {
  my $self = shift;
  my $req = shift;
  my %args = @_;

  my @errors = $self->_check_required(1001, \%args, qw(name user psw psw1));
  push (@errors, { 
    code    => 1002,
    param   => 'psw1',
    message => 'Second password does not match first' 
  }) if (!scalar(@errors) and $args{psw} ne $args{psw1});
  die [ -32602, 'Invalid params', \@errors] if scalar(@errors);

  my $session = Plack::Session->new($req->{'env'});
  my $dbh = &{$self->get_dbh};
  my $rv = $dbh->selectall_arrayref('select * FROM app.register(?, ?, ?, ?, ?)', {'Slice' => {} },
    $session->id,
    $args{user},
    $args{psw},
    $args{name},
    $self->{'config'}{'login_on_register'}
  ) or die $self->_db_error($dbh->errstr);
  if (ref $rv eq 'ARRAY' and $rv->[0]) {
    if ($self->{'config'}{'login_on_register'}) {
      # Авторизуем пользователя по факту регистрации
      $session->set('profile', $rv->[0]);
    }
    return 1;
  } else {
    die [ 1015, 'Registration closed' ]
  }
}

#----------------------------------------------------------------------
# applied sub - login user
# on success - save in session and return his account attributes
sub login {
  my $self = shift;
  my $req = shift;
  my %args = @_;
  my @errors = $self->_check_required(1001, \%args, qw(user psw));
  die [ -32602, 'Invalid params', \@errors] if scalar(@errors);

  my $session = Plack::Session->new($req->{'env'});
  my $dbh = &{$self->get_dbh};
  my $rv = $dbh->selectall_arrayref('select * from app.login(?, ?, ?)', {'Slice' => {} },
    $session->id,
    $args{user},
    $args{psw}
  ) or die $self->_db_error($dbh->errstr);
  if (ref $rv eq 'ARRAY' and $rv->[0]) {
    $session->set('profile', $rv->[0]);
    return 1;
  } else {
    die [ -32602, 'Invalid params', [{ code => 1004, param => 'user', message => 'User unknown'}]];
  }
}

#----------------------------------------------------------------------
# applied sub - make user session as anonymous
sub logout {
  my $self = shift;
  my $req = shift;
  my $session = Plack::Session->new($req->{'env'});
  $session->remove('profile');
  return 1;
}

#----------------------------------------------------------------------
# applied sub - DB call for apache.account_purge
sub account_purge {
  my $self = shift;
  my $req = shift;
  my $interval = shift;
  my $dbh = &{$self->get_dbh};
  # my $rv = $dbh->selectall_arrayref('select * from app.account_purge(?)', undef, $interval,
  my $rv = $dbh->selectall_arrayref('select * from app.account_purge()', undef,
  ) or die $self->_db_error($dbh->errstr);
  if (ref $rv eq 'ARRAY' and $rv->[0]) {
    return $rv->[0];
  } else {
    die [ 1001, 'DB error: Result expected' ]
  }
}

#----------------------------------------------------------------------
# applied sub - DB call for apache.account_purge
sub session_purge {
  my $self = shift;
  my $req = shift;

  my ($purge_sid, $session);
  if ($req) {
    $session = Plack::Session->new($req->{'env'});
    $purge_sid = $session->id;
  }
  die [ 1002, 'sid not found'] unless ($purge_sid);
  my $dbh = &{$self->get_dbh};
  my $rv = $dbh->selectall_arrayref('select * from app.session_purge(?)', undef,
    $purge_sid
  ) or die $self->_db_error($dbh->errstr);
  if (ref $rv eq 'ARRAY' and $rv->[0]) {
    $session->remove('profile');
    return $rv->[0][0];
  } else {
    die [ 1003, 'DB error: Result expected' ]
  }
}

1;
