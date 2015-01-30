#!perl6

use v6;
use Slang::Tuxic;

use Test;
use Text::CSV;

my $csv = Text::CSV.new (binary => 1);

my @attrib  = ("quote_char", "escape_char", "sep_char");
my @special = ('"', "'", ",", ";", "\t", "\\", "~");
# Add undef, once we can return undef
my @input   = ( "", 1, "1", 1.4, "1.4", " - 1,4", "1+2=3", "' ain't it great '",
    '"foo"! said the `bär', q{the ~ in "0 \0 this l'ne is \r ; or "'"} );
my $ninput  = @input.elems;
my $string  = join "=", "", @input, "";
my %fail;

ok (1, "--     qc     ec     sc     ac");

sub combi (*%attr)
{
    my $combi = join " ", "--", map { sprintf "%6s", %attr{$_}.perl; },
        @attrib, "always_quote";
    ok (1, $combi);

    # use legal non-special characters
    is ($csv.allow_whitespace (0), False,  "Reset allow WS");
    is ($csv.sep_char    ("\x03"), "\x03", "Reset sep");
    is ($csv.quote_char  ("\x04"), "\x04", "Reset quo");
    is ($csv.escape_char ("\x05"), "\x05", "Reset esc");

    # Set the attributes and check failure
    my %state;
    for sort keys %attr -> $attr {
        my $v = %attr{$attr};
        try {
            $csv."$attr"(%attr{$attr});

            CATCH { %state{$csv.error_diag.error} ||= $csv.error_diag.message; }
            };
        }
    if (%attr{"sep_char"} eq %attr{"quote_char"} ||
        %attr{"sep_char"} eq %attr{"escape_char"}) {
        ok (%state{1001}.defined, "Illegal combo");
        is (%state{1001}, rx{sep_char is equal to}, "Illegal combo");
        }
    else {
        ok (!%state{1001}.defined, "No char conflict");
        }
    if (!%state{1001}.defined and
            %attr{"sep_char"}    ~~ m/[\r\n]/ ||
            %attr{"quote_char"}  ~~ m/[\r\n]/ ||
            %attr{"escape_char"} ~~ m/[\r\n]/
            ) {
        ok (%state{1003}.defined, "Special contains eol");
        is (%state{1003}, rx{in main attr not}, "Illegal combo");
        }
    if (%attr{"allow_whitespace"} and
            %attr{"quote_char"}  ~~ m/^[ \t]/ ||
            %attr{"escape_char"} ~~ m/^[ \t]/
            ) {
        #diag (join " -> ** " => $combi, join ", " => sort %state);
        ok (%state{1002}.defined, "Illegal combo under allow_whitespace");
        is (%state{1002}, rx{allow_whitespace with}, "Illegal combo");
        }
    %state and return;

    # Check success
    is ($csv."$_"(), %attr{$_},  "check $_") for sort keys %attr;

    my $ret = $csv.combine (@input);

    ok ($ret, "combine");
    ok (my $str = $csv.string, "string");
    SKIP: {
        ok (my $ok = $csv.parse ($str), "parse");

        unless ($ok) {
            %fail{"parse"}{$combi} = $csv.error_input;
            skip "parse () failed",  3;
            }

        ok (my @ret = $csv.fields, "fields");
        unless (@ret) {
            %fail{"fields"}{$combi} = $csv.error_input;
            skip "fields () failed", 2;
            }

        is (@ret.elems, $ninput,   "$ninput fields");
        unless (@ret.elems == $ninput) {
            %fail{'$#fields'}{$combi} = $str;
            skip "# fields failed",  1;
            }

        my $ret = join "=", "", @ret, "";
        is ($ret, $string,          "content");
        }
    } # combi

for ( False, True    ) { my $aw = $_;
for ( False, True    ) { my $aq = $_;
for ( @special       ) { my $qc = $_;
for ( @special, "+"  ) { my $ec = $_;
for ( @special, "\0" ) { my $sc = $_;
    combi (
        sep_char         => $sc,
        quote_char       => $qc,
        escape_char      => $ec,
        always_quote     => $aq,
        allow_whitespace => $aw,
        );
     }
    }
   }
  }
 }

=finish

foreach my $fail (sort keys %fail) {
    print STDERR "Failed combi for $fail ():\n",
                 "--     qc     ec     sc     ac\n";
    foreach my $combi (sort keys %{$fail{$fail}}) {
        printf STDERR "%-20s - %s\n", map { _readable $_ } $combi, $fail{$fail}{$combi};
        }
    }
1;
