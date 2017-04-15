package DeparseDumper;
BEGIN {
	require B::Deparse;
	*B::Deparse::const = \&B::Deparse::const_dumper;
}
1;
