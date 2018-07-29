package DBIx::Class::Helper::Row::Enumeration;

# ABSTRACT: Add methods for emum values

use v5.10.1;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

use Ref::Util  ();
use Sub::Quote ();

# RECOMMEND PREREQ: Ref::Util::XS

our $VERSION = 'v0.1.0';

=head1 SYNOPSIS

In your result class:

  use base qw/DBIx::Class::Core/;

  __PACKAGE__->load_components(qw/ Helper::Row::Enumeration /);

  __PACKAGE__->add_column(

    foo => {
        data_type => 'enum',
        extra     => {
            list => [qw/ good bad ugly /],
        },
    },

with a row:

  if ($row->is_good) { ... }

=cut

sub add_columns {
    my ( $self, @cols ) = @_;

    $self->next::method(@cols);

    my $class = Ref::Util::is_ref($self) || $self;

    foreach my $col (@cols) {

        next if ref $col;

        $col =~ s/^\+//;

        my $info = $self->column_info($col);

        next unless $info->{data_type} eq 'enum';

        my $handlers = $info->{extra}{handles} //= sub { "is_" . $_[0] };

        next unless $handlers;

        if ( Ref::Util::is_plain_coderef($handlers) ) {
            $info->{extra}{handles} =
              { map { $handlers->( $_, $col, $class ) // 0 => $_ }
                  @{ $info->{extra}{list} } };
            $handlers = $info->{extra}{handles};
        }

        DBIx::Class::Exception->throw("handles is not a hashref")
          unless Ref::Util::is_plain_hashref($handlers);

        foreach my $handler ( keys %$handlers ) {
            next unless $handler;
            my $value = $handlers->{$handler} or next;

            my $method = "${class}::${handler}";

            DBIx::Class::Exception->throw("${method} is already defined")
              if $self->can($method);

            Sub::Quote::quote_sub $method,
              qq{ my \$val = \$_[0]->get_column("${col}"); }
              . qq{ defined(\$val) && \$val eq "${value}" };

        }

    }

    return $self;
}

1;
