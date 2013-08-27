package P3Base::ProcHash;

use strict;
use warnings;

our $VERSION   = '0.20';

use Carp;

#----------------------------------------------------------------------
sub TIEHASH {
  my $pkg = shift;
  my $usg = qq{usage: tie %procs, "$pkg", \$proc_factory [, \$item_format];};
  my $pf = shift or croak $usg;
  my $format = shift || 'sub';
  my (@args) = @_;
  my $h = {
    pf => $pf,          # ProcFactory object
    format => $format,  # Item format (plack or sub), see ProcFactory::proc
    args => \@args,     # Request args ($args[0] used as $env for format 'sub')
  };
  bless $h, $pkg;
} # TIEHASH

#----------------------------------------------------------------------
# hash item access - call ProcFactory::proc
sub FETCH {
  my ($self, $key) = @_;
  return $self->{pf}->proc($self->{format}, $key, @{$self->{args}});
} # FETCH

# Do nothing, but method def needed
sub STORE { }

# Do nothing, but method def needed by Data::Dumper
sub FIRSTKEY { }

#----------------------------------------------------------------------

1;

__END__

=pod

=head1 NAME

P3Base::ProcHash - tie P3Base::ProcFactory RPC as hash

=head1 SYNOPSIS

  # Setup ProcFactory
  my $pf = App->new(root => $root, config => \%cfg, get_dbh => $get_dbh);

  # Attach procedures to JSON::RPC::Dispatcher
  tie my %procs, 'P3Base::ProcHash', $pf, 'plack';
  my $rpc = JSON::RPC::Dispatcher->new;
  $rpc->rpcs(\%procs);

  # Attach procedures to Plack::Middleware::TemplateToolkit
  tie my %procs, 'P3Base::ProcHash', $pf, 'sub', Plack::Request->new($env);
  $env->{'tt.vars'} ||= {};
  $env->{'tt.vars'}{'api'} = \%procs;


=head1 DESCRIPTION

This package presents P3Base::ProcFactory procedures as hash for use in 

=over 4

=item Template (Template Toolkit 2)

=item JSON::RPC::Dispatcher

=back

See Tie::Hash for details

=head1 METHODS

=over 4

=item B<TIEHASH ( $pkg, $proc_factory [, $item_format [, $arg ]] )>

The constructor called by tie and takes the following arguments:

=over 4

=item pkg - class name

=item proc_factory - P3Base::ProcFactory object

=item item_format - plack|sub, name of returned item structure

=item arg - request object for 'sub' item format

=back


=item B<FETCH( $key )>

This method caled internally when hash element requested.

=back

=head1 BUGS

None known yet.

=head1 AUTHOR

Alexey Kovrizhkin E<lt>lekovr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2013, Alexey Kovrizhkin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
