#=======================================================================
#    ____  ____  _____              _    ____ ___   ____
#   |  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#   | |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#   |  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#   |_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#   A Perl Module Chain to faciliate the Creation and Modification
#   of High-Quality "Portable Document Format (PDF)" Files.
#
#   Copyright 1999-2005 Alfred Reibenschuh <areibens@cpan.org>.
#
#=======================================================================
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the
#   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#   Boston, MA 02111-1307, USA.
#
#   $Id$
#
#=======================================================================
package PDF::API2::Resource::CIDFont::TrueType;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::CIDFont;

    use PDF::API2::Basic::TTF::Font;
    use PDF::API2::Resource::CIDFont::TrueType::FontFile;

    use POSIX;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource::CIDFont );

    ( $VERSION ) = '2.005';

}
no warnings qw[ deprecated recursion uninitialized ];

=item $font = PDF::API2::Resource::CIDFont::TrueType->new $pdf, $file, %options

Returns a font object.

Defined Options:

    -encode ... specify fonts encoding for non-utf8 text.

    -nosubset ... disables subsetting.

=cut

sub new {
    my ($class,$pdf,$file,@opts) = @_;
    my %opts=();
    %opts=@opts if((scalar @opts)%2 == 0);
    $opts{-encode}||='latin1';
    my ($ff,$data)=PDF::API2::Resource::CIDFont::TrueType::FontFile->new($pdf,$file,@opts);

    $class = ref $class if ref $class;
    my $self=$class->SUPER::new($pdf,$data->{apiname}.pdfkey().'~'.time());
    $pdf->new_obj($self) if(defined($pdf) && !$self->is_obj($pdf));

    $self->{' data'}=$data;

    my $des=$self->descrByData;

    $self->{'BaseFont'} = PDFName($self->fontname);

    my $de=$self->{' de'};

    $de->{'FontDescriptor'} = $des;
    $de->{'Subtype'} = PDFName($self->iscff ? 'CIDFontType0' : 'CIDFontType2');
    ## $de->{'BaseFont'} = PDFName(pdfkey().'+'.($self->fontname).'~'.time());
    $de->{'BaseFont'} = PDFName($self->fontname);
    $de->{'DW'} = PDFNum($self->missingwidth);
    if($opts{-noembed} != 1)
    {
    	$des->{$self->data->{iscff} ? 'FontFile3' : 'FontFile2'}=$ff;
    }
    unless($self->issymbol) {
        $self->encodeByName($opts{-encode});
        $self->data->{encode}=$opts{-encode};
        $self->data->{decode}='ident';
    }

    if($opts{-nosubset}) {
        $self->data->{nosubset}=1;
    }


    $self->{' ff'} = $ff;
    $pdf->new_obj($ff);

    $self->{-dokern}=1 if($opts{-dokern});

    return($self);
}


sub fontfile { return( $_[0]->{' ff'} ); }
sub fontobj { return( $_[0]->data->{obj} ); }

=item $font = PDF::API2::Resource::CIDFont::TrueType->new_api $api, $file, %options

Returns a truetype-font object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api 
{
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $self->{' api'}=$api;

    $api->{pdf}->out_obj($api->{pages});
    return($obj);
}

sub wxByCId 
{
    my $self=shift @_;
    my $g=shift @_;
    my $t = $self->fontobj->{'hmtx'}->read->{'advance'}[$g];
    my $w;

    if(defined $t) 
    {
        $w = int($t*1000/$self->data->{upem});
    } 
    else 
    {
        $w = $self->missingwidth;
    }

    return($w);
}

sub haveKernPairs 
{
    my $self = shift @_;
    return($self->fontfile->haveKernPairs(@_));
}

sub kernPairCid
{
    my $self = shift @_;
    return($self->fontfile->kernPairCid(@_));
}

sub subsetByCId 
{
    my $self = shift @_;
    return if($self->iscff);
    my $g = shift @_;
    $self->fontfile->subsetByCId($g);
}
sub subvec 
{
    my $self = shift @_;
    return(1) if($self->iscff);
    my $g = shift @_;
    $self->fontfile->subvec($g);
}

sub glyphNum { return ( $_[0]->fontfile->glyphNum ); }

sub outobjdeep 
{
    my ($self, $fh, $pdf, %opts) = @_;

    return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

    my $notdefbefore=1;

    my $wx=PDFArray();
    $self->{' de'}->{'W'} = $wx;
    my $ml;

    foreach my $w (0..(scalar @{$self->data->{g2u}} - 1 )) 
    {
        if($self->subvec($w) && $notdefbefore==1) 
        {
            $notdefbefore=0;
            $ml=PDFArray();
            $wx->add_elements(PDFNum($w),$ml);
        #    $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
            $ml->add_elements(PDFNum($self->wxByCId($w)));
        } 
        elsif($self->subvec($w) && $notdefbefore==0) 
        {
            $notdefbefore=0;
        #    $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
            $ml->add_elements(PDFNum($self->wxByCId($w)));
        } 
        else 
        {
            $notdefbefore=1;
        }
        # optimization for cjk
        #if($self->subvec($w) && $notdefbefore==1 && $self->data->{wx}->[$w]!=$self->missingwidth) {
        #    $notdefbefore=0;
        #    $ml=PDFArray();
        #    $wx->add_elements(PDFNum($w),$ml);
        #    $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        #} elsif($self->subvec($w) && $notdefbefore==0 && $self->data->{wx}->[$w]!=$self->missingwidth) {
        #    $notdefbefore=0;
        #    $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        #} else {
        #    $notdefbefore=1;
        #}
    }

    $self->SUPER::outobjdeep($fh, $pdf, %opts);
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut
