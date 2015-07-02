require 'rexml/document'
require 'fileutils'
include REXML

def _usage
  puts 'Usage: dst_processor destination_xml taxonomy_xml html_out_dir'
  puts '  destination_xml:    Loaction of destinations XML file'
  puts '  taxonomy_xml:       Location of taxonomy XML file'
  puts '  html_out_dir:       Directory to store generated HTML files'
end

#
# Open specified file and attempt to parse as XML and generate new REXML Document
#
def load_XML(file)
  begin
    xml_file = File.open(file)
    xml_obj = Document.new(xml_file)
    xml_file.close
  rescue => e
    puts "ERROR: Unable to create XML object from file: #{file}"
    puts e.message
    puts e.backtrace
    exit 1
  end
  return xml_obj
end

#
# Create the HTML file for the specified location in the specified directory
#
def create_HTML_file(loc_name, content, out_dir)
  File.open("#{out_dir}/#{loc_name}.html", 'w') do |f|
    f.write(HEADER_TEXT)
    f.write("<h1>Lonely Planet: #{loc_name}</h1>")
    f.write(NAV_TITLE)
    f.write($navigation_html)
    f.write(BLOCK_TITLE)
    f.write("<h1><li class='first'><a href='#'>#{loc_name}</a></li></h1>")
    f.write(MAIN_BLOCK)
    f.write(content)
    f.write(CLOSE_HTML)
  end
end

#
# Iterate through the hierarchy and generate the HTML files for each location
#
def generate_HTML(loc_hier, out_dir)
  loc_hier.each do |loc|
    id = loc[:id]
    loc_name = loc[:location]

    generate_HTML(loc[:sub_loc], out_dir) unless loc[:sub_loc].empty?

    loc_content = $destinations.elements["destination[@atlas_id='#{id}']"]
    content = ''

    loc_content.elements.each do |el|
      content += '<p>'
      section_title = el.elements[1].name.split('_').each(&:capitalize!).join(' ')
      content += "<h2>#{section_title}</h2>"
      content += '<p>'
      content_string = el.elements[1].elements[1].cdatas[0].to_s
      content += content_string.gsub("\n\n\n", '<br><p>').gsub("\n\n", '<p>').gsub("\n", '<br>')
      content += '<p>'
    end
    create_HTML_file(loc_name, content, out_dir)
  end
end

#
# Generate the location hierarchy from the taxonomy XML
#
def generate_hierarchy(node, id = nil)
  loc = {}
  $navigation_html += '<ul><li>'
  node.each_element do |element|
    if element.name == 'node_name' && !id.nil?
      loc[:id] = id
      loc[:location] = element.text
      loc[:sub_loc] = []
      $navigation_html += "<a href='#{loc[:location]}.html'>#{loc[:location]}</a>"
    else
      loc[:sub_loc] << generate_hierarchy(element, element.attributes['atlas_node_id'])
    end
  end
  $navigation_html += '</li></ul>'
  return loc
end

#
# Main program begins here
#
if ARGV.length != 3
  puts 'Not enough args'
  usage
  exit 1
end

destination_file = ARGV[0]
taxonomy_file = ARGV[1]
output_dir = ARGV[2]

unless File.exist?(destination_file)
  puts "Destination File: #{destination_file} does not exist"
  _usage
  exit 1
end

unless File.exist?(taxonomy_file)
  puts "Taxonomy File: #{taxonomy_file} does not exist"
  _usage
  exit 1
end

unless Dir.exist?(output_dir)
  puts "Output Directory: #{output_dir} does not exist - attempting to create"
  begin
    Dir.mkdir(output_dir)
  rescue => e
    puts "ERROR: Unable to create output dir: #{output_dir}"
    puts e.message
    puts e.backtrace
    exit 1
  end
end

#
# Copy in the dir containing css
#
FileUtils.cp_r('static', "#{output_dir}")

#
# Get the root node of both XML objects
# destinations is made global as we want to access it when generating the
# content for each page
#
taxonomies = load_XML(taxonomy_file).root
$destinations = load_XML(destination_file).root

location_hierarchy = []

#
# navigation_html contains the navigation code- made global as it is the same
# for each page (can access any location from any page), and is updated when
# generating the hierarchy
#
$navigation_html = '<nav>'

#
# Create the html content which is the same for each page
#
HEADER_TEXT = "<!DOCTYPE html>
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

NAV_TITLE = "
                </div>
                <div id='wrapper'>
                    <div id='sidebar'>
                        <div class='block'>
                            <h3>Navigation</h3>
                            <div class='content'>
                                <div class='inner'>"

BLOCK_TITLE = "
                                </div>
                            </div>
                        </div>
                    </div>
                    <div id='main'>
                        <div class='block'>
                            <div class='secondary-navigation'>
                                <ul>"

MAIN_BLOCK = "
                                </ul>
                                <div class='clear'></div>
                            </div>
                            <div class='content'>
                                <div class='inner'>"

CLOSE_HTML = "
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
# Generation of the location hierarchy makes some assumptions on the xml format:
#   If a node has the attribute atlas_node_id, then it is a location, and will
#   have at least one child node.
#   That child node will be node_name, and contain the name of the location.
#   Any other child nodes will be locations within the node location region
#   e.g. the node for South Africa contains the child node ->
#   <node_name>South Africa</node_name>,
#   as well as a child node for Cape Town.
#
taxonomies.elements[1].each_element do |el|
  if el.attributes.include?('atlas_node_id')
    location_hierarchy << generate_hierarchy(el, el.attributes['atlas_node_id'])
  end
end
$navigation_html += '</nav>'

generate_HTML(location_hierarchy, output_dir)

exit
