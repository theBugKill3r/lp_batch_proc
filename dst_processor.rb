require 'rexml/document'
include REXML

def _usage
	puts "Usage: dst_processor destination_xml taxonomy_xml html_out_dir"
	puts "  destination_xml:    Loaction of destinations XML file"
	puts "  taxonomy_xml:       Location of taxonomy XML file"
	puts "  html_out_dir:       Directory to store generated HTML files"
end

#
# Open specified file and attempt to parse as XML and generate new REXML Document
#
def _loadXML(file)
	begin
		xmlFile = File.open(file)
		xmlObj = Document.new(xmlFile)
		xmlFile.close
	rescue => e
		puts "ERROR: Unable to create XML object from file: #{file}"
		puts e.message
		puts e.backtrace
		File.close(file)
		exit 1
	end

	return xmlObj
end

#
# Create the HTML file for the specified location in the specified directory
#
def _createHTMLFile(locName, content, outDir)
    begin
        File.open("#{outDir}/#{locName}.html", 'w') do |f|
            f.write($headerText)
		    f.write("<h1>Lonely Planet: #{locName}</h1>")
	        f.write($navTitle)
		    f.write($navigationHTML)
            f.write($blockTitle)
		    f.write("<h1><li class='first'><a href='#'>#{locName}</a></li></h1>")
		    f.write($mainBlock)
	        f.write(content)
            f.write($closeHTML)
	    end
    rescue => e
        puts "ERROR: Unable to create HTML file for location: #{locName}"
        puts e.message
        puts e.backtrace
        exit 1
    end
end

#
# Iterate through the hierarchy and generate the HTML files for each location
#
def _generateHTML(locHier, outDir, parent=nil)
	locHier.each do |loc|
		id = loc[:id]
		locName = loc[:location]
		
		if !loc[:sub_loc].empty?
			_generateHTML(loc[:sub_loc], outDir, locName)
		end
		
		loc_content = $destinations.elements["destination[@atlas_id='#{id}']"]
		
		content = ""
		loc_content.elements.each do |el|	
			content += "<p>"
			section_title = el.elements[1].name.split('_').each { |word| word.capitalize! }.join(" ")	
			content += "<h2>#{section_title}</h2>"
			content += "<p>"
            content_string = el.elements[1].elements[1].cdatas()[0].to_s
			content += content_string.gsub("\n\n\n", "<br><p>").gsub("\n\n", "<p>").gsub("\n", "<br>")
			content += "<p>"
		end
		
		_createHTMLFile(locName, content, outDir)
	end
end

#
# Generate the location hierarchy from the taxonomy XML
#
def _generateHierarchy(node, id=nil)
	loc = Hash.new
	$navigationHTML += "<ul><li>"
	node.each_element do |element|
		
		if element.name == "node_name" and !id.nil?
			loc[:id] = id
			loc[:location] = element.text
			loc[:sub_loc] = Array.new
			$navigationHTML += "<a href='#{loc[:location]}.html'>#{loc[:location]}</a>"
			
		else
			loc[:sub_loc] << _generateHierarchy(element, element.attributes["atlas_node_id"])
		end
		
	end
	$navigationHTML += "</li></ul>"
	
	return loc
end

#
# Main program begins here
#
if ARGV.length != 3
	puts "Not enough args"
	_usage
	exit 1
end

destinationFile = ARGV[0]
taxonomyFile = ARGV[1]
outputDir = ARGV[2]

if !File.exist?(destinationFile)
	puts "Destination File: #{destinationFile} does not exist"
	_usage
	exit 1
end

if !File.exist?(taxonomyFile)
	puts "Taxonomy File: #{taxonomyFile} does not exist"
	_usage
	exit 1
end

if !Dir.exist?(outputDir)
	puts "Output Directory: #{outputDir} does not exist - attempting to create"
    begin
	    Dir.mkdir(outputDir)
    rescue => e
        puts "ERROR: Unable to create output dir: #{outputDit}"
        puts e.message
        puts e.backtrace
        exit 1
    end
end

destinationXML = _loadXML(destinationFile)
taxonomyXML = _loadXML(taxonomyFile)

#
# Get the root node of both XML objects
# destinations is made global as we want to access it when generating the content for each page
#
taxonomies = taxonomyXML.root
$destinations = destinationXML.root

locationHierarchy = Array.new

#
# navigationHTML contains the navigation code- made global as it is the same for each page 
# (can access any location from any page)
#
$navigationHTML = "<nav>"

#
# Create the html content which is the same for each page as globals
#
$headerText = "<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv='content-type' content='text/html; charset=UTF-8'>
        <title>Lonely Planet</title>
        <link href='static/all.css' media='screen' rel='stylesheet' type='text/css'>
    </head>
    <body>
        <div id='container'>
            <div id='header'>
                <div id='logo'>"

$navTitle = "
                </div>
                <div id='wrapper'>
                    <div id='sidebar'>
                        <div class='block'>
                            <h3>Navigation</h3>
                            <div class='content'>
                                <div class='inner'>"

$blockTitle = "
                                </div>
                            </div>
                        </div>
                    </div>
                    <div id='main'>
                        <div class='block'>
                            <div class='secondary-navigation'>
                                <ul>"

$mainBlock = "
                                </ul>
                                <div class='clear'></div>
                            </div>
                            <div class='content'>
                                <div class='inner'>"

$closeHTML = "
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>"

#
# Generation of the location hierarchy makes some assumptions on the xml format -
#   If a node has the attribute atlas_node_id, then it is a location, and will have at least one child node.
#   That child node will be node_name, and contain the name of the location.
#   Any other child nodes will be locations within the node location region 
#   e.g. the node for South Africa contains the child node -> <node_name>South Africa</node_name>, as well as a child node for Cape Town.
#
taxonomies.elements[1].each_element do |el|
	if el.attributes.include?("atlas_node_id")
		locationHierarchy << _generateHierarchy(el, el.attributes["atlas_node_id"])
	end
end
$navigationHTML += "</nav>"

_generateHTML(locationHierarchy, outputDir)

exit
