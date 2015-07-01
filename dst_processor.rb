require 'rexml/document'
include REXML

def _usage
	puts "Usage: dst_processor destination_xml taxonomy_xml html_out_dir"
	puts "  destination_xml:    Loaction of destinations XML file"
	puts "  taxonomy_xml:       Location of taxonomy XML file"
	puts "  html_out_dir:       Directory to store generated HTML files"
end

def _loadXML(file)
	begin
		return Document.new(File.open(file))
	rescue => e
		puts "ERROR: Unable to create XML object from file: #{file}"
		puts e.message
		puts e.backtrace
		File.close(file)
		exit!
	end
end

def _createHTMLFile(id, locName, content, outDir)
	outFile = File.new("#{outDir}/#{locName}.html", 'w')
	outFile.write('<!DOCTYPE html>')
	outFile.write('<html>')
	outFile.write('<head>')
	outFile.write('<meta http-equiv="content-type" content="text/html; charset=UTF-8">')
	outFile.write('<title>Lonely Planet</title>')
	outFile.write('<link href="static/all.css" media="screen" rel="stylesheet" type="text/css">')
	outFile.write('</head>')
	outFile.write('<body>')
	outFile.write('<div id="container">')
	outFile.write('<div id="header">')
	outFile.write('<div id="logo">')
        outFile.write("<h1>Lonely Planet: #{locName}</h1>")
      	outFile.write('</div>')
      	outFile.write('<div id="wrapper">')
        outFile.write('<div id="sidebar">')
        outFile.write('<div class="block">')
        outFile.write('<h3>Navigation</h3>')
        outFile.write('<div class="content">')
        outFile.write('<div class="inner">')
        outFile.write(@navigationHTML)
        outFile.write('</div>')
        outFile.write('</div>')
        outFile.write('</div>')
        outFile.write('</div>')
        outFile.write('<div id="main">')
	outFile.write('<div class="block">')
        outFile.write('<div class="secondary-navigation">')
        outFile.write('<ul>')
        outFile.write("<h1><li class='first'><a href='#'>#{locName}</a></li></h1>")
        outFile.write('</ul>')
        outFile.write('<div class="clear"></div>')
        outFile.write('</div>')
        outFile.write('<div class="content">')
        outFile.write('<div class="inner">')
       	outFile.write(content)
        outFile.write('</div>')
        outFile.write('</div>')
        outFile.write('</div>')
	outFile.write('</div>')
	outFile.write('</div>')
	outFile.write('</body>')
	outFile.write('</html>')
	outFile.close
end

def _generateHTML(locHier, outDir, parent=nil)
	locHier.each do |loc|
		id = loc[:id]
		locName = loc[:location]
		
		if !loc[:sub_loc].empty?
			_generateHTML(loc[:sub_loc], outDir, locName)
		end
		
		loc_content = @destinations.elements["destination[@atlas_id='#{id}']"]
		
		content = ""
		loc_content.elements.each do |el|	
			content += "<p>"
			section_title = el.elements[1].name.split('_').each { |word| word.capitalize! }.join(" ")	
			content += "<h2>#{section_title}</h2>"
			content += "<p>"
			content += el.elements[1].elements[1].cdatas()[0].to_s
			content += "<p>"
		end
		
		_createHTMLFile(id, locName, content, outDir)
	end
end

def _generateHierarchy(node, id=nil)
	loc = Hash.new
	@navigationHTML += "<ul><li>"
	node.each_element do |element|
		
		if element.name == "node_name" and !id.nil?
			loc[:id] = id
			loc[:location] = element.text
			loc[:sub_loc] = Array.new
			@navigationHTML += "<a href='#{loc[:location]}.html'>#{loc[:location]}</a>"
			
		else
			loc[:sub_loc] << _generateHierarchy(element, element.attributes["atlas_node_id"])
		end
		
	end
@navigationHTML += "</li></ul>"
	
	return loc
end


if ARGV.length != 3
	puts "Not enough args"
	_usage
	exit!	
end

destinationFile = ARGV[0]
taxonomyFile = ARGV[1]
outputDir = ARGV[2]

if !File.exist?(destinationFile)
	puts "Destination File: #{destinationFile} does not exist"
	_usage
	exit!
end

if !File.exist?(taxonomyFile)
	puts "Taxonomy File: #{taxonomyFile} does not exist"
	_usage
	exit!
end

if !Dir.exist?(outputDir)
	puts "Output Directory: #{outputDir} does not exist"
	Dir.create(outputDir)
end

destinationXML = _loadXML(destinationFile)
taxonomyXML = _loadXML(taxonomyFile)

taxonomies = taxonomyXML.root
@destinations = destinationXML.root

locationHierarchy = Array.new
@navigationHTML = "<nav>"
taxonomies.elements[1].each_element do |el|
	if el.attributes.include?("atlas_node_id")
		locationHierarchy << _generateHierarchy(el, el.attributes["atlas_node_id"])
	end
end
@navigationHTML += "</nav>"

puts "-----"
puts @navigationHTML
puts "-----"

_generateHTML(locationHierarchy, outputDir)


