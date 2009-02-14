package Class::Monadic;

use 5.008_001;
use strict;
use warnings;

our $VERSION = '0.01';

use Exporter qw(import);
our @EXPORT_OK   = qw(monadic);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use Carp ();
use Data::Util ();
use Scalar::Util ();
use Hash::FieldHash ();
#use Class::Method::Modifiers::Fast ();

Hash::FieldHash::fieldhash my %Meta;

sub _cannot_initialize{
	Carp::croak 'Cannot initialize a monadic object without object references';
}

sub monadic{
	my($object) = @_;

	return __PACKAGE__->initialize($object);
}

sub initialize{
	my($class, $object) = @_;
	ref($object) or _cannot_initialize();

	return $Meta{$object} ||= $class->_new($object);
}

sub _new{
	my($metaclass, $object) = @_;

	my $class = Scalar::Util::blessed($object) or _cannot_initialize();

	my $meta = bless {
		class   => $class,
		id      => sprintf('0x%x', Scalar::Util::refaddr($object)),

		object  => undef,
		isa     => undef,
		sclass  => undef,
	}, $metaclass;

	my $sclass      = $class . '::' . $meta->{id};
	my $sclass_isa  = do{ no strict 'refs'; \@{$sclass . '::ISA'} };

	$meta->{sclass} = $sclass;
	$meta->{isa}    = $sclass_isa;

	Scalar::Util::weaken( $meta->{object} = $object );

	@{$sclass_isa} = ($class);

	bless $object, $sclass; # re-bless
	return $meta;
}


sub name{
	my($meta) = @_;

	return $meta->{class};
}

sub add_method{
	my $meta = shift;

	Data::Util::install_subroutine($meta->{sclass}, @_);
	return;
}

sub add_field{
	my $meta = shift;

	foreach my $name(@_){
		Data::Util::is_string($name)
			or Carp::croak('You must supply a field name');

		my $field;

		$meta->add_method(
			"get_$name" => sub{
				if(@_ > 1){
					Carp::croak("Too many arguments for get_$name");
				}
				return $field;
			},
			"set_$name" => sub{
				if(@_ > 2){
					Carp::croak("Cannot set multiple values for set_$name");
				}
				$field = $_[1];
				return $_[0]; # chained
			},
		);
	}
	return;
}

sub add_modifier{
	my $meta = shift;

	require Class::Method::Modifiers::Fast;

	Class::Method::Modifiers::Fast::_install_modifier($meta->{sclass}, @_);
	return;
}

sub inject_base{
	my($meta, @components) = @_;

	# NOTE: In 5.10.0, do{unshift @ISA, @classes} may cause 'uninitialized' warnings
	@{$meta->{isa}} = (
		(grep{ not $meta->{object}->isa($_) } @components),
		@{$meta->{isa}},
	);
	return;
}


sub DESTROY{
	my($meta) = @_;

	my $original_stash = Data::Util::get_stash($meta->{class});

	my $sclass_stashgv = delete $original_stash->{$meta->{id} . '::'};
	%{$sclass_stashgv} = ();

	return;
}

1;
__END__

=head1 NAME

Class::Monadic - Provides monadic methods (a.k.a. singleton methods)

=head1 VERSION

This document describes Class::Monadic version 0.01.

=head1 SYNOPSIS

	use Class::Monadic;

	my $dbh1 = DBI->connect(...);

	Class::Monadic->initialize($dbh1)->add_method(
		foo => sub{ ... },
	);

	$dbh1->foo(...); # OK

	my $dbh2 = DBI->connect(...);

	$dbh2->foo(); # throws "Can't locate object method ..."
	              # because foo() is $dbh1 specific.

	# import a syntax sugar to make an object monadic
	use Class::Monadic qw(monadic);

	monadic($dbh1)->inject_base(qw(SomeComponent OtherComponent));
	# now $dbh1 is-a both SomeComponent and OtherComponent

	monadic($dbh1)->add_field(qw(x y z));
	$dbh1->set_x(42);
	print $dbh->get_x(); # => 42

=head1 DESCRIPTION

C<Class::Monadic> provides per-object classs, B<monadic classes>. It is also
known as B<singleton classes> in other languages, e.g. C<Ruby>.

Monadic classes is used in order to define B<monadic methods>
(a.k.a. B<singleton methods>), which are only available at the specific object
they are defined into.

=head1 INTERFACE

=head2 Exportable functions

=head3 monadic($object)

A syntax sugar to C<< Class::Monadic->initialize($object) >>.

=head2 Class methods

=head3 C<< Class::Monadic->initialize($object) >>

Makes I<$object> monadic, and returns C<Class::Monadic> instance, I<$meta>.

=head2 Instance methods

=head3 C<< $meta->name >>

Returns the name of the monadic class.

=head3 C<< $meta->add_method(%name_code_pairs) >>

Adds methods into the monadic class.

=head3 C<< $meta->add_field(@field_names) >>

Adds fields and accessors named I<get_$name>/I<set_$name> into the monadic class.

Fields are not stored in the object. Rather, stored in the monadic class.

=head3 C<< $meta->add_modifier($type, @method_names, $code) >>

Adds method modifiers to specific methods,  Using C<Class::Method::Modifiers::Fast>.

I<$type> is must be C<before>, C<around> or C<after>.

Example:

	monadic($obj)->add_modifier(before => foo => sub{ ... });
	monadic($obj)->add_modifier(around => qw(foo bar baz),
		sub{
			my $next = shift;
			my(@args) = @_;
			# ...
			return &{$next};
		}
	);
	monadic($obj)->add_modifier(after => xyzzy => sub{ ... });

=head3 C<< $meta->inject_base(@component_classes) >>

Adds I<@component_classes> into the is-a hierarchy of the monadic class.

=head1 DEPENDENCIES

Perl 5.8.1 or later.

C<Data::Util>.

C<Hash::FieldHash>.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<Class::MOP>.

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Goro Fuji (gfx). Some rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
