require 'rubygems'
require 'bundler/setup'

# require your gems as usual
require 'parse-ruby-client'
require 'nokogiri'
require 'ap'
require 'active_support/core_ext/hash'
require 'json'
require 'byebug'


# init
Parse.init :application_id => "jWB4DslP0qm6Fvma02kNB8Y6LeHK47UWBo3OItQI",
           :api_key        => "W4I6v13p1Fk8WCYfEhqOu35JEmdXGYdJYuRZJQPV",
           :quiet          => false

$PATH = File.expand_path File.dirname(__FILE__)

# load all xml files
@files ||= Dir.glob("xmldata/*.xml")

@files.each do |file|
  file_path     = $PATH + '/' + file
  doc           = Nokogiri::XML(File.open(file_path, 'r'))
  hash_data     = Hash.from_xml(doc.to_s)
  course_hash   = hash_data['GolfCourse']

  # now trying to uploading to Parse
  golf_course = Parse::Object.new("GolfCourse").tap do |rec|
    rec['uid']      = course_hash['CourseID']
    rec['name']     = course_hash['CourseName']
    rec['location'] = Parse::GeoPoint.new({"latitude" => 0.0, "longitude" => 0.0})
    rec['address']  = course_hash['StateCode']


    if course_hash['GreenNames'].present?
      course_hash['GreenNames']['GolfGreen'].each do |green|
        rec.array_add('greens', green['GreenName'])
      end
    end

    if course_hash['Sessions'].present?
      course_hash['Sessions']['GolfSession'].each_with_index do |session, session_idx|
        rec.array_add('sessions', session['SessionName'])

        if session['GolfHoles'].present?
          session['GolfHoles']['GolfHole'].each do |golf_hole|
            ap golf_hole
            ap "--------------"

            Parse::Object.new("GolfHole").tap do |rec_h|
              rec_h['par']          = golf_hole['PAR']
              rec_h['hcp']          = golf_hole['HDCP']
              rec_h['session_id']   = session_idx
              rec_h['order']        = golf_hole['HoleDisplayOrder']

              if golf_hole['HoleDistances']['GolfHoleDistance'].is_a?(Array)
                golf_hole['HoleDistances']['GolfHoleDistance'].each_with_index do |hole_distance, distance_idx|
                  rec_h["tee#{distance_idx}"] = hole_distance['Distance']
                end
              elsif golf_hole['HoleDistances']['GolfHoleDistance'].is_a?(Hash)
                rec_h["tee0"] = golf_hole['HoleDistances']['GolfHoleDistance']['Distance']
              end


              if golf_hole['HoleCoordinates'].present?
                golf_hole['HoleCoordinates']['GolfHoleCoordinate'].each_with_index do |hole_coordinate, coordinate_idx|
                  if hole_coordinate['CoordinateType'].to_s == '0'
                    rec_h["tee_loc"] = [hole_coordinate['latitude'].to_f, hole_coordinate['longitude'].to_f]
                  else
                    rec_h["green#{coordinate_idx}_loc"] = [hole_coordinate['latitude'].to_f, hole_coordinate['longitude'].to_f]
                  end
                end
              end

              rec_h.save
            end


            if golf_hole['HoleDistances']['GolfHoleDistance'].is_a?(Array)
              golf_hole['HoleDistances']['GolfHoleDistance'].each do |hole_distance|
                rec.array_add('tees', hole_distance['TeePositionName'])
              end

            elsif golf_hole['HoleDistances']['GolfHoleDistance'].is_a?(Hash)
              rec.array_add('tees', golf_hole['HoleDistances']['GolfHoleDistance']['TeePositionName'])
            end
          end
        end
      end
    end
  end
  results = golf_course.save
  sleep(1)
end
