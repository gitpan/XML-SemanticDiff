package XML::SemanticDiff;

use strict;
use vars qw/$VERSION/;

$VERSION = '0.50';

use XML::Parser;
use Digest::MD5;

sub new {
    my ($proto, %args) = @_;
    my $class = ref($proto) || $proto;
    my $self  = { 'keepdata'       => $args{keepdata}       || undef,
                  'keeplinenums'   => $args{keeplinenums}   || undef,
                  'diffhandler'    => $args{diffhandler}    || undef
                };

    require XML::SemanticDiff::BasicHandler unless defined $args{diffhandler};

    bless ($self, $class);
    return $self;
}

sub read_xml {
    my $self = shift;
    my $p = XML::Parser->new( Style => 'Stream',
                              Pkg   => 'PathFinder',
                              'Non-Expat-Options' => $self,
                              Namespaces => 1);

    my $doc = $_[0] !~ /\n/g && -f $_[0] ? $p->parsefile($_[0]) : $p->parse($_[0]);

    return $doc;
}

# Okay, it's pretty basic...
#
# We flatten each doc tree to a Perl hash where the keys are "fully qualified" 
# XPath expressions (/root[1]/element[3]) that represent the unique location
# of each XML element, then compare the two hashes. 
#
# Just loop over all the elements of the first hash- if the same key exists
# in the second, you compare the text and attributes and delete it. Any
# keys not found in the second hash are declared 'missing', and any keys leftover
# in the second hash after looping through the elements in the first are 'rogues'. 

sub compare {
    my $self = shift;
    my ($from_xml, $to_xml) = @_;

    my $from_doc = ref($from_xml) eq 'HASH' ? $from_xml : $self->read_xml($from_xml);
    my $to_doc = $self->read_xml($to_xml);

    my @warnings = ();

    my $handler = $self->{diffhandler} || XML::SemanticDiff::BasicHandler->new(%$self);


    # fire the init handler
    push (@warnings, $handler->init($self)) if $handler->can('init');

    # loop the elements
    foreach my $element (sort keys (%$from_doc)) {

        # element existence check
        if (defined $to_doc->{$element}) {

            # element value test
            unless ($from_doc->{$element}->{TextChecksum} eq $to_doc->{$element}->{TextChecksum}) {
                push (@warnings, $handler->element_value($element, 
                                                         $to_doc->{$element}, 
                                                         $from_doc->{$element}))
                          if $handler->can('element_value');
            }
        
            # namespace test
            unless ($from_doc->{$element}->{NamespaceURI} eq $to_doc->{$element}->{NamespaceURI}) {
                push (@warnings, $handler->namespace_uri($element, 
                                                         $to_doc->{$element}, 
                                                         $from_doc->{$element}))
                           if $handler->can('namespace_uri');
            }
    
            # attribute tests
            foreach my $attr (keys(%{$from_doc->{$element}->{Attributes}})) {
 
                 # attr existence check
                 if (defined ($to_doc->{$element}->{Attributes}->{$attr})) {

                     # attr value test
                     if ($to_doc->{$element}->{Attributes}->{$attr} ne $from_doc->{$element}->{Attributes}->{$attr}){
                        push (@warnings, $handler->attribute_value($attr, 
                                                                   $element, 
                                                                   $to_doc->{$element},
                                                                   $from_doc->{$element}))
                              if $handler->can('attribute_value');
                     }
                     delete $to_doc->{$element}->{Attributes}->{$attr};
                 }
                 else {
                     push (@warnings, $handler->missing_attribute($attr, 
                                                                  $element, 
                                                                  $to_doc->{$element}, 
                                                                  $from_doc->{$element}))
                           if $handler->can('missing_attribute'); 
                 }                
            }

            # rogue attrs
            foreach my $leftover (keys(%{$to_doc->{$element}->{Attributes}})) {
                push (@warnings, $handler->rogue_attribute($leftover, 
                                                           $element, 
                                                           $to_doc->{$element}, 
                                                           $from_doc->{$element}))
                     if $handler->can('rogue_attribute');
            }
            
            delete $to_doc->{$element};
        }
        else {            
            push (@warnings, $handler->missing_element($element, $from_doc->{$element}))
                      if $handler->can('missing_element');          
        }
    }

    # rogue elements
    foreach my $leftover ( keys (%$to_doc) ) {
        push (@warnings, $handler->rogue_element($leftover, $to_doc->{$leftover})) 
             if $handler->can('rogue_element');
    }                 

    push (@warnings, $handler->final($self)) if $handler->can('final');
            
    return @warnings;
}

1;

package PathFinder;
use strict;
    
my $descendents = {};
my $position_index = {};
my $char_accumulator = {};
my $doc = {};
my $opts = {};

sub StartTag {
    my ($expat, $element) = @_;
    my %attrs = %_;
            
    my @context = $expat->context;
    my $context_length = scalar (@context);
    my $parent = $context[$context_length -1];
    push (@{$descendents->{$parent}}, $element) if $parent;
    $position_index->{"$element"}++;
    my $test_context;
 
    if (@context){
        $test_context = '/' . join ('/', map { $_ . '[' . $position_index->{$_} . ']' } @context);
    }   
        
    $test_context .= '/' . $element . '[' . $position_index->{$element} . ']';

    $doc->{"$test_context"}->{NamespaceURI} = $expat->namespace($element) || "";
    $doc->{"$test_context"}->{Attributes}   = \%attrs || {};
    $doc->{"$test_context"}->{TagStart}     = $expat->current_line if $opts->{keeplinenums};

}

sub EndTag {
    my ($expat, $element) = @_;
    
    
    my @context = $expat->context;
    my $test_context;
            
    if (@context){
        $test_context = '/' . join ('/', map { $_ . '[' . $position_index->{$_} . ']' } @context);
    }
         
    $test_context .= '/' . $element . '[' . $position_index->{$element} . ']';
    
    #warn "in end, test context is $test_context \n";
        
    my $text = delete $char_accumulator->{$element} || "";
    
    my $ctx = Digest::MD5->new;
    $ctx->add("$text");
    $doc->{"$test_context"}->{TextChecksum} = $ctx->b64digest;


    if ($opts->{keepdata}) {
        $doc->{"$test_context"}->{CData} = $text;
    }
    
    
    if (defined ( $descendents->{$element})) {
        my $seen = {};
        foreach my $child (@{$descendents->{$element}}) {
            next if $seen->{$child};
            #reset the relative counter
            $position_index->{$child} = 0;
            $seen->{$child}++;
        }
    }
    
    $doc->{"$test_context"}->{TagEnd} = $expat->current_line if $opts->{keeplinenums};
        
}

sub Text {
    my $expat = shift;
    
    my $element = $expat->current_element;
    my $char = $_;
    
    $char =~ s/^\s*//;
    $char =~ s/\s*$//;
    $char =~ s/\s+/ /g;
    $char_accumulator->{$element} .= $char if $char;
    
}
        
sub StartDocument {
    my $expat = shift;
    $doc = {};
    $descendents = {};
    $position_index = {};
    $char_accumulator = {};
    $opts = $expat->{'Non-Expat-Options'}
}
        
sub EndDocument {
    return $doc;
}
    
sub PI {
    my ($expat, $target, $data) = @_;
    my $attrs = {};
    $position_index->{$target}++;

    foreach my $pair (split /\s+/, $data) {
        $attrs->{$1} = $2 if $pair =~ /^(.+?)=["'](.+?)["']$/;
    }

    my $slug = '?' . $target . '[' . $position_index->{$target} . ']';

    $doc->{$slug}->{Attributes} = $attrs || {};
    $doc->{$slug}->{TextChecksum} = "1";
    $doc->{$slug}->{NamespaceURI} = "";
    $doc->{$slug}->{TagStart} = $expat->current_line if $opts->{keeplinenums};
    $doc->{$slug}->{TagEnd} = $expat->current_line if $opts->{keeplinenums};

}   

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

XML::SemanticDiff - Perl extension for comparing XML documents' abstract structure and contents.

=head1 SYNOPSIS

  use XML::SemanticDiff;
  my $diff = XML::SemanticDiff->new();

  foreach my $change ($diff->compare($file, $file2)) {
      print "$change->{message} in context $change->{context}\n";
  }

  # or, if you want line numbers:

  my $diff = XML::SemanticDiff->new(keeplinenums => 1);

  foreach my $change ($diff->compare($file, $file2)) {
      print "$change->{message} (between lines $change->{startline} and $change->{endline})\n";
  }

=head1 DESCRIPTION

XML::SematicDiff provides a way to compare the contents and structure of two XML documents. By default, it returns a list of
hashrefs where each hashref describes a single difference between the two docs.

=head1 METHODS

=head2 $obj->new([%options])

Ye olde object constructor.

The new() method recognizes the following options:

=over 4

=item * keeplinenums

When this option is enabled XML::SemanticDiff will add the 'startline' and 'endline' properties (containing the line numbers
for the reported element's start tag and end tag) to each warning. For attribute events these numbers reflect the start and
end tags of the element which contains that attribute. 

=item * keepdata

When this option is enabled XML::SemanticDiff will add the 'old_value' and 'new_value' properties to each warning. These
properties contain, surprisingly, the old and new values for the element or attribute being reported. 

In the case of missing elements or attributes (those in the first document, not in the second) only the 'old_value' property
will be defined. Similarly, in the case of rogue elements or attributes (those in the second document but not in the
first) only the 'new_value' property will be defined. 

Note that using this option will greatly increase the amount of memory used by your application.

=item * diffhandler

Taking a blessed object as it's sole argument, this option provides a way to hook the basic semantic diff engine into your own
custom handler class. 

Please see the section on 'CUSTOM HANDLERS' below.

=back

=head1 CUSTOM HANDLERS

Internally, XML::SemanticDiff uses an event-based model somewhat reminscent of SAX2 where the various 'semantic diff events'
are handed off to a seperate handler class to cope with the details. For most general cases where the user only cares about 
reporting the differences between two docs, the default handler, XML::SemanticDiff::BasicHandler, will probably  
suffice. However, it is often desirable to add side-effects to the diff process (updating datastores, widget callbacks,  
etc.) and a custom handler allows you to be creative with what to do about differences between two XML documents and how
those differences are reported through the compare() method.

BETA WARNING more docs needed here. For now, look at the code in XML::SemainticDiff::BasicHandler and the distribution's test
files for examples. 

Note that if a given method is not implemented in your custom handler class, XML::SemanticDiff will not complain; but it means
that all of those events will be silently ignored. Consider yourself warned. 

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2000 Kip Hampton. All rights reserved. This program is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut
