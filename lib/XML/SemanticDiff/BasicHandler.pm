package XML::SemanticDiff::BasicHandler;

use strict;
use vars qw/$VERSION/;

$VERSION = '0.50';

sub new {       
    my ($proto, %args) = @_;
    my $class = ref($proto) || $proto;
    my $self  = \%args;
    bless ($self, $class);
    return $self;
}

sub rogue_element {
    my $self = shift;
    my ($element, $properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);
    my $info = {context => $parent,
                message => "Rogue element '$element_name' in element '$parent'."};
    
    if ($self->{keeplinenums}) {
        $info->{startline} = $properties->{TagStart};
        $info->{endline}   = $properties->{TagEnd};
    }
 
    if ($self->{keepdata}) {
        $info->{new_value} = $properties->{CData};
    }    
    return $info;
}

sub missing_element {
    my $self = shift;
    my ($element, $properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);
    my $info = {context => $parent,
                message => "Child element '$element_name' missing from element '$parent'."};
                 
    if ($self->{keeplinenums}) {
        $info->{startline} = $properties->{TagStart};
        $info->{endline}   = $properties->{TagEnd};
    }
    if ($self->{keepdata}) {
        $info->{old_value} = $properties->{CData};
    }
    return $info;
}

sub element_value {
    my $self = shift;
    my ($element, $new_properties, $old_properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);

    my $info = {context => $element,
                message => "Character differences in element '$element_name'."};
                       
    if ($self->{keeplinenums}) {
        $info->{startline} = $new_properties->{TagStart};
        $info->{endline}   = $new_properties->{TagEnd};
    }
                  
    if ($self->{keepdata}) {
        $info->{old_value} = $old_properties->{CData};
        $info->{new_value} = $new_properties->{CData};
    }

    return $info;
}

sub rogue_attribute {
    my $self = shift;    
    my ($attr, $element, $properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);
    my $info = {context  => $element,
                message  => "Rogue attribute '$attr' in element '$element_name'."};
        
    if ($self->{keeplinenums}) {
        $info->{startline} = $properties->{TagStart};
        $info->{endline}   = $properties->{TagEnd};
    }

    if ($self->{keepdata}) {
        $info->{new_value} = $properties->{Attributes}->{$attr};
    }
    return $info;
}

sub missing_attribute {
    my $self = shift;
    my ($attr, $element, $new_properties, $old_properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);
    my $info = {context  => $element,
                message  => "Attribute '$attr' missing from element '$element_name'."};
         
    if ($self->{keeplinenums}) {
        $info->{startline} = $new_properties->{TagStart};
        $info->{endline}   = $new_properties->{TagEnd};
    }

    my @blarg = keys (%{$old_properties->{Attributes}});

    if ($self->{keepdata}) {
        $info->{old_value} = $old_properties->{Attributes}->{$attr};
    }
    return $info;
}

sub attribute_value {
    my $self = shift;
    my ($attr, $element, $new_properties, $old_properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);
    my $info = {context  => $element,
                message  => "Attribute '$attr' has different value in element '$element_name'."};
                  
    if ($self->{keeplinenums}) {
        $info->{startline} = $new_properties->{TagStart};
        $info->{endline}   = $new_properties->{TagEnd};
    }
        
    if ($self->{keepdata}) {
        $info->{old_value} = $old_properties->{Attributes}->{$attr};
        $info->{new_value} = $new_properties->{Attributes}->{$attr};
    }
    return $info;
}

sub namespace_uri {
    my $self = shift;
    my ($element, $new_properties, $old_properties) = @_;
    my ($element_name, $parent) = parent_and_name($element);
    my $info = {context  => $element,
                message  => "Element '$element_name' within different namespace."};
            
    if ($self->{keeplinenums}) {
        $info->{startline} = $new_properties->{TagStart};
        $info->{endline}   = $new_properties->{TagEnd};
    }
                            
    if ($self->{keepdata}) {
        $info->{old_value} = $old_properties->{NamspaceURI};
        $info->{new_value} = $new_properties->{NamspaceURI};
    }
    return $info;
}

sub parent_and_name {
    my $element = shift;
    my @steps = split('/', $element);   
    my $element_name = pop (@steps);
    my $parent = join '/', @steps;
    $element_name =~ s/\[\d+\]$//;
    return ($element_name, $parent);
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

XML::SemanticDiff - Perl extension for blah blah blah

=head1 SYNOPSIS

  use XML::SemanticDiff;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for XML::SemanticDiff was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut

