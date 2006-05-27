#!/bin/bash 
#
# Roma: transform TEI ODD files to schema and documentation
#
# Sebastian Rahtz, April 2005
# copyright: TEI Consortium
# license: GPL
# $Id$
#

makeODD() 
{
    echo "1. expand and simplify ODD "
    if test "x$translatelang" = "x"
    then
	xsltproc -o $N.compiled.odd \
	    --stringparam TEIC $TEIC \
	    --stringparam TEISERVER $TEISERVER  \
	    --stringparam localsource "$LOCAL"  \
	    $TEIXSLDIR/odds/odd2odd.xsl $ODD 
    else
	echo  [translated to language $lang]
	xsltproc \
	     --stringparam TEIC $TEIC \
	    --stringparam TEISERVER $TEISERVER  \
	    --stringparam localsource "$LOCAL"  \
	    $TEIXSLDIR/odds/odd2odd.xsl $ODD  | \
	xsltproc -o $N.compiled.odd \
	    --stringparam TEISERVER $TEISERVER  \
	    --stringparam lang $translatelang  \
	    --stringparam verbose true  \
	    $TEIXSLDIR/odds/translate-odd.xsl - 
    fi
}

makeRelax() 
{
    echo "2. make Relax NG from compiled ODD"
    xsltproc $PATTERN $DEBUG  \
	     --stringparam TEIC $TEIC \
	     --stringparam lang $lang  \
             --stringparam outputDir $RESULTS       \
             $TEIXSLDIR/odds/odd2relax.xsl $N.compiled.odd
    (cd $RESULTS; \
    echo "3. make Relax NG compact from XML"; \
    trang $N.rng $N.rnc  || die " trang conversion to RNC fails"; \
    xmllint --format $N.rng > $$.xml; mv $$.xml $N.rng )
 }

makeXSD()
{
    echo "4. make XSD from Relax NG"
    (cd $RESULTS; \
    trang  -o disable-abstract-elements $N.rng $N.xsd || die " trang fails";\
    test -f xml.xsd && perl -p -i -e 's+\"xml.xsd\"+\"http://www.w3.org/2004/10/xml.xsd\"+' $N.xsd)
}

makeDTD()
{
    echo "5. make DTD from compiled ODD"
    xsltproc  $DEBUG \
	    --stringparam lang $lang  \
	    --stringparam TEIC $TEIC \
            --stringparam outputDir $RESULTS       \
            $TEIXSLDIR/odds/odd2dtd.xsl $N.compiled.odd
}

makeHTMLDOC() 
{
    echo "8. make HTML documentation"
    xsltproc $DEBUG     \
	-o $N.doc.html \
	--stringparam TEIC $TEIC \
        --stringparam lang $lang  \
	--stringparam STDOUT true \
	--stringparam splitLevel -1 \
	$TEIXSLDIR/odds/odd2html.xsl $N.compiled.odd
    echo created $N.doc.html 
}

makePDFDOC() 
{
    echo "7. make PDF documentation"
    xsltproc $DEBUG     \
	--stringparam TEIC $TEIC \
        --stringparam lang $lang  \
	-o $N.doc.tex \
	$TEIXSLDIR/latex/tei.xsl $N.doc.xml
    pdflatex $N.doc.tex
    echo created $N.doc.pdf and $N.doc.tex 
}

makeXMLDOC() 
{
    echo "6. make expanded documented ODD"
    xsltproc $DEBUG     \
        --stringparam TEISERVER $TEISERVER  \
	--stringparam localsource "$LOCAL"  \
	--stringparam TEIC $TEIC \
        --stringparam lang $lang  \
	-o $N.doc.xml \
	$TEIXSLDIR/odds/odd2lite.xsl $N.compiled.odd 
    echo created $N.doc.xml 
}


die()
{
    echo; echo
    echo "ERROR: $@."
    D=`date "+%Y-%m-%d %H:%M:%S.%N"`
    echo "This was a fatal error. $D"
    exit 1
}

usageMsg()
{
echo "Roma -- reads in a TEI ODD file that specifies a schema, and tangles it"
echo "into RelaxNG schema, DTD, and W3C XML Schema, and can weave it into an"
echo "expanded, self-documented single ODD file. Note that only the first"
echo "<schemaSpec> encountered in the input ODD file is processed; all others"
echo "are ignored."
echo "  Usage: roma [options] schemaspec [output_directory]"
echo "  options, shown with defaults:"
echo "  --xsl=$TEIXSLDIR"
echo "  --teiserver=$TEISERVER"
echo "  --localsource=$LOCALSOURCE # local copy of P5 sources"
echo "  options, binary switches:"
echo "  --doc              # create expanded documented ODD (TEI Lite XML)"
echo "  --translate=LANG   # translate tags to LANG (es, de, fr)"
echo "  --lang=LANG        # use LANG for interface and documentation where possible"
echo "  --dochtml          # create HTML version of doc"
echo "  --patternprefix=STRING # prefix relax patterns with STRING"
echo "  --docpdf           # create PDF version of doc"
echo "  --nodtd            # suppress DTD creation"
echo "  --norelax          # suppress RelaxNG creation"
echo "  --noxsd            # suppress W3C XML Schema creation"
echo "  --noteic           # suppress TEI-specific features"
echo "  --debug            # leave temporary files, etc."
exit 1
}

# --------- main routine starts here --------- #
TEISERVER=http://tei.oucs.ox.ac.uk/Query/
TEIXSLDIR=/usr/share/xml/tei/stylesheet
LOCALSOURCE=
LOCAL=
TEIC=true
lang=en
translatelang=
debug=false
dtd=true
relax=true
xsd=true
doc=false
docpdf=false
dochtml=false
PATTERNPREFIX=
while test $# -gt 0; do
  case $1 in
    --xsl=*)       TEIXSLDIR=`echo $1 | sed 's/.*=//'`;;
    --lang=*)      lang=`echo $1 | sed 's/.*=//'`;;
    --translate=*) translatelang=`echo $1 | sed 's/.*=//'`;;
    --doc)         doc=true;;
    --dochtml)     dochtml=true;;
    --docpdf)      docpdf=true;;
    --teiserver=*) TEISERVER=`echo $1 | sed 's/.*=//'`;;
    --localsource=*) LOCALSOURCE=`echo $1 | sed 's/.*=//'`;;
    --nodtd)       dtd=false;;
    --norelax)     relax=false;;
    --noxsd)       xsd=false;;
    --noteic)      TEIC=false;;
    --patternprefix=*) PATTERNPREFIX=`echo $1 | sed 's/.*=//'`;;
    --debug)       debug=true;;
    --help)        usageMsg;;
     *) if test "$1" = "${1#--}" ; then 
	   break
	else
	   echo "WARNING: Unrecognized option '$1' ignored"
	   echo "For usage syntax issue $0 --help"
	fi ;;
  esac
  shift
done
ODD=${1:?"no schemaspec (i.e., ODD file) supplied; for usage syntax issue $0 --help"}
RESULTS=${2:-RomaResults}
H=`pwd`
D=`date "+%Y-%m-%d %H:%M:%S"`
echo "========= $D Roma starts, info:"
echo "Test for software: xmllint, xsltproc, trang, and perl"
which xmllint || die "you do not have xmllint"
which xsltproc || die "you do not have xsltproc"
which trang || die "you do not have trang"
which perl || die "you do not have perl"
test -f $ODD || die "file $ODD does not exist"
echo "TEI stylesheet tree: $TEIXSLDIR"
test -d $TEIXSLDIR/odds || \
     GET -e -d $TEIXSLDIR/odds/odd2odd.xsl > /dev/null || \
     die "stylesheet location $TEIXSLDIR is not accessible"
N=$(xsltproc $TEIXSLDIR/odds/extract-schemaSpec-ident.xsl $1 | head -1)
N=${N:?"Unable to ascertain ident= of <schemaSpec>"}
echo "Results to: $RESULTS"
mkdir -p $RESULTS || die "cannot make directory $RESULTS"
D=`date "+%Y-%m-%d %H:%M:%S.%N"`
echo "Process $ODD to create $N{.dtd|.xsd|.doc.xml|.rng|.rnc} in $RESULTS"
echo "========= $D Roma starts, execution:"
if test "x$PATTERNPREFIX" = "x"
then
   PATTERN=""
else
   PATTERN=" --stringparam patternPrefix $PATTERNPREFIX"
fi
if $debug
then
    DEBUG=" --stringparam verbose true"
else
    DEBUG=""
fi
if test "x$LOCALSOURCE" = "x"
then
    echo using $TEISERVER to access TEI database
else
    echo using $LOCALSOURCE to gather information about TEI 
cat > subset.xsl <<EOF
<xsl:stylesheet version="1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <tei:TEI>
      <xsl:copy-of select=".//tei:elementSpec"/>
      <xsl:copy-of select=".//tei:macroSpec"/>
      <xsl:copy-of select=".//tei:classSpec"/>
      <xsl:copy-of select=".//tei:moduleSpec"/>
    </tei:TEI>
</xsl:template>
</xsl:stylesheet>
EOF
xmllint --noent --xinclude $LOCALSOURCE | xsltproc -o tei$$.xml $DEBUG subset.xsl - || die "failed to extract subset from $LOCALSOURCE "
LOCAL=$H/tei$$.xml
fi

makeODD
$relax && makeRelax
$relax && $xsd && makeXSD
$dtd && makeDTD
$dochtml && doc=true
$docpdf && doc=true
if $doc
then 
    makeXMLDOC
    if $docpdf
    then
	makePDFDOC
    fi
fi
$dochtml && makeHTMLDOC
$debug || rm  $N.compiled.odd
test -f subset.xsl && rm subset.xsl
test -f tei$$.xml && rm tei$$.xml
D=`date "+%Y-%m-%d %H:%M:%S.%N"`
echo "========= $D Roma ends"