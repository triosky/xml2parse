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
           :quiet          => true

$PATH = File.expand_path File.dirname(__FILE__)

# load all xml files
@files ||= Dir.glob("xmldata/*.xml")

@files.each do |file|
  file_path     = $PATH + '/' + file
  done_path     = $PATH + '/done/' + file
  doc           = Nokogiri::XML(File.open(file_path, 'r'))
  hash_data     = Hash.from_xml(doc.to_s)
  course_hash   = hash_data['GolfCourse']
  
  # now trying to uploading to Parse
  course = Parse::Query.new("GolfCourse").eq("uid",course_hash['CourseID']).get
  
  if course != []
    puts "#{course} Course #{course_hash['CourseName']}  Exists"
    next
  else
    puts "Uploading #{course_hash['CourseName']}  #{file}"
    batch = Parse::Batch.new
    golf_course = Parse::Object.new("GolfCourse").tap do |rec|
      rec['uid']      = course_hash['CourseID']
      rec['name']     = course_hash['CourseName']
      rec['location'] = Parse::GeoPoint.new({"latitude" => 0.0, "longitude" => 0.0})
      rec['address']  = course_hash['StateCode']


      if course_hash['GreenNames'].present?
        if course_hash['GreenNames']['GolfGreen'].is_a?(Array)
          course_hash['GreenNames']['GolfGreen'].each do |green|
            rec.array_add('greens', green['GreenName'])
          end
        elsif course_hash['GreenNames']['GolfGreen'].is_a?(Hash)
          rec.array_add('greens', course_hash['GreenNames']['GolfGreen']['GreenName'])
        end
      end

      if course_hash['Sessions'].present?
        #populate tees
        first_hole = course_hash['Sessions']['GolfSession'].first['GolfHoles']['GolfHole'].first
        if first_hole['HoleDistances']['GolfHoleDistance'].is_a?(Array)
          first_hole['HoleDistances']['GolfHoleDistance'].each do |hole_distance|
            rec.array_add('tees', hole_distance['TeePositionName'])
          end
        elsif first_hole['HoleDistances']['GolfHoleDistance'].is_a?(Hash)
          rec.array_add('tees', first_hole['HoleDistances']['GolfHoleDistance']['TeePositionName'])
        end

        course_hash['Sessions']['GolfSession'].each_with_index do |session, session_idx|
          rec.array_add('sessions', session['SessionName'])

          if session['GolfHoles'].present?
            session['GolfHoles']['GolfHole'].each do |golf_hole|
              ap golf_hole
              ap "--------------"

              hole = Parse::Object.new("GolfHole").tap do |rec_h|
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
              end
              # hole.save
              batch.create_object(hole)
            end
          end
        end
      end
    end
    batch_result = batch.run!
    puts "#{batch_result}"
    batch_result.each do |r|
      if r["success"].present?
        p = Parse::Pointer.new({"className" => "GolfHole", "objectId" => r["success"]["objectId"]})
        golf_course.array_add_relation("holes", p)
      end
    end
    # batch.create_object(golf_course)
    # batch.run!
    golf_course.save
    File.rename file_path, done_path
    sleep(5)
  end
end
