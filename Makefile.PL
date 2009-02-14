use strict;
use warnings;
use inc::Module::Install;

name 'Class-Monadic';
all_from 'lib/Class/Monadic.pm';

requires 'Exporter' => 5.57;
requires 'Data::Util';
requires 'Hash::FieldHash';
requires 'Class::Method::Modifiers::Fast';

test_requires 'Test::More' => 0.62;

tests 't/*.t';
author_tests 'xt';

WriteMakefile(
	clean => {FILES => q(
		Class-Monadic-* *.stackdump
		cover_db
		nytprof
		*.out
	)},
);
