#test-fonts.pl
# script helping you find a font that supports given symbol/glyph
# from https://github.com/polybar/polybar/wiki/Fonts#find-fonts-for-glyphs
#
# invoke like   $ perl find-icon-font.pl "😠"
#
use strict;
use warnings;
use Font::FreeType;
my ($char) = @ARGV;
foreach my $font_def (`fc-list`) {
    my ($file, $name) = split(/: /, $font_def);
    my $face = Font::FreeType->new->face($file);
    my $glyph = $face->glyph_from_char($char);
    if ($glyph) {
        print $font_def;
    }
}
