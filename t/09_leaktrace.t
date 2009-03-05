#!perl -w

use strict;

use constant HAS_LEAKTRACE => eval q{ use Test::LeakTrace 0.07; 1 };

use Test::More HAS_LEAKTRACE ? (tests => 3) : (skip_all => 'require Test::LeakTrace');
use Test::LeakTrace;

use Class::Monadic;

my $nleaks = $] == 5.010_000 ? 1 : 0;

leaks_cmp_ok{
	my $o = bless [42];

	Class::Monadic->initialize($o)->add_method(hello => sub {
		my $i;
		$i++;
	});
	$o->hello();

} '<=', $nleaks, 'add_method';


leaks_cmp_ok{
	my $o = bless [];

	Class::Monadic->initialize($o)->add_field(foo => [qw(banana apple)]);
	$o->set_foo('banana');

} '<=', $nleaks, 'add_field';

leaks_cmp_ok{
	my $o = bless [];
	{ package X; }

	Class::Monadic->initialize($o)->inject_base('X');
} '<=', $nleaks, 'inject_base';
