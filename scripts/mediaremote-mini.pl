#!/usr/bin/perl
use strict;
use warnings;
use DynaLoader;

my $lib = shift @ARGV or die "Usage: mediaremote-mini.pl <dylib> [symbol]\n";
my $symbol = shift @ARGV // 'adapter_get_env';

my $handle = DynaLoader::dl_load_file($lib, 0)
  or die "Failed to load dylib: " . DynaLoader::dl_error() . "\n";
my $sym = DynaLoader::dl_find_symbol($handle, $symbol)
  or die "Failed to find symbol '$symbol'\n";
my $func = DynaLoader::dl_install_xsub("main::$symbol", $sym);
&$func();
