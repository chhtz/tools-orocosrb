#! /usr/bin/env ruby

require 'roby/standalone'
require 'roby/log/event_stream'
require 'roby/log/plan_rebuilder'
require 'orocos/roby'

class Decoder < Roby::LogReplay::PlanRebuilder
    def added_task_child(time, parent, rel, child, info)
        parent, rel, child = super
        if rel == Orocos::RobyPlugin::Flows::DataFlow
            puts "#{time}: added #{parent.model.short_name} => #{child.model.short_name}"
            info.each do |(from, to), policy|
                puts "  #{from} => #{to}: #{policy}"
            end
        end
    end
    def removed_task_child(time, parent, rel, child)
        parent, rel, child = super
        raise if rel == Orocos::RobyPlugin::RequiredDataFlow
        if rel == Orocos::RobyPlugin::Flows::DataFlow
            puts "#{time}: removed #{parent.model.short_name} => #{child.model.short_name}"
        end
    end
end

stream  = Roby::LogReplay::EventFileStream.open(ARGV.shift)
Decoder.new.analyze_stream(stream)
