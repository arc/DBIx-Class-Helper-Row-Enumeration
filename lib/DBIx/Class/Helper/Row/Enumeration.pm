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

=head1 DESCRIPTION

This plugin is inspired by L<MooseX::Enumeration>.

Suppose your database has a column with an enum value. Checks against
string values are prone to typos:

  if ($row->result eq 'faol') { ... }

when instead you wanted

  if ($row->result eq 'fail') { ... }

Using this plugin, you can avoid common bugs by checking against a
method instead:

  if ($row->is_fail) { ... }

=head1 Overriding method names

You can override method names by adding an extra C<handles> attribute
to the column definition:

    bar => {
        data_type => 'enum',
        extra     => {
            list   => [qw/ good bad ugly /],
            handles => {
                good_bar => 'good',
                coyote   => 'ugly',
            },
        },
    },

Note that only methods you specify will be added. In the above case,
there is no "is_bad" method added.

The C<handles> attribute can also be set to a code reference so that
method names can be generated dynamically:

    baz => {
        data_type => 'enum',
        extra     => {
            list   => [qw/ good bad ugly /],
            handles => sub {
                my ($value, $col, $class) = @_;

                return undef if $value eq 'deprecated';

                return "is_${col}_${value}";
            },
        },
    },
);

If the function returns C<undef>, then no method will be generated for
that value.

If C<handles> is set to "0", then no methods will be generated for the
column at all.

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

=head1 KNOWN ISSUES

See also L</BUGS> below.

=head2 Overlapping enum values

Multiple columns with overlapping enum values will cause an error.
You'll need to specify a handler to rename methods or skip them
altogether.

=head2 Autogenerated Classes

You cannot override the configuration with autogenerated classes.
This issue will be addressed in a later version.

=head1 SEE ALSO

  L<MooseX::Enumeration>

=head1 append:AUTHOR

The initial development of this module was sponsored by Science Photo
Library L<https://www.sciencephoto.com>.

=cut

1;
