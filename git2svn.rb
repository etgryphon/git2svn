#! /usr/bin/env ruby

# ******************************
# GIT 2 SVN Script
# ******************************
# == Synopsis 
#
# == Examples
#
#
# == Usage 
#
# == Author
# Evin Grano, Mike Ball
#
# == Copyright
#   Copyright (c) 2008 Eloqua Corp. All Rights Rserved.
#

require 'find'
require 'ftools'
require 'fileutils'
class Git2Svn

  def initialize(arguments, stdin)
      #init stuff....
      # TODO:  Check for the configuration file to grab the SVN_ROOT Directory
  end
  
  def run
    
    # TODO: Create a temp SVN Directory to checkout the latest copy of the SVN repository
    
    # Change to the SVN Root directory and get the latest to correct collisions
    Dir.chdir(SVN_ROOT)
    `svn update`
    
    puts 'Started the SVN Directory Traverse and delete';
    svn_excludes = SVN_DIR_EXCLUDE.split(',')
    search_and_destroy(SVN_ROOT, svn_excludes)
  
    # Copy all files from GIT to SVN
    git_excludes = GIT_DIR_EXCLUDE.split(',')
    traverse_and_copy(GIT_ROOT, SVN_ROOT, git_excludes) 
    
    # Calibrate the SVN repo to the new changes
    # TODO:  Add the ability to grab the latest commit message from GIT
    svn_calibration("New Stuff")
    
  end
  
  protected
  # CONSTANTS
  SVN_ROOT = '/path/to/svn/repository'
  SVN_DIR_EXCLUDE = '.svn'
  GIT_ROOT = '/path/to/git/repository'
  GIT_DIR_EXCLUDE = '.git,public,log'
   
  def search_and_destroy(src_path, exclude_dirs)
    puts 'Start In: ' + src_path
    Find.find(src_path) do |entry|
      if File.file?(entry)
        File.delete(entry)
      elsif File.directory?(entry)
        exclude_dirs.each do |x|
          Find.prune if (File.basename(entry) == x.strip)
        end
      else
        puts 'Error'
      end
    end
  end
  
  def traverse_and_copy(src_path, target_path, exclude_dirs)
    puts 'Start In: ' + src_path
    Find.find(src_path) do |entry|
      # Trim base directory from the current file or directory 
      file_path = File.expand_path(entry)
      file_path.gsub!(src_path, '')
      if File.file?(entry)
        File.copy("#{src_path}#{file_path}","#{target_path}#{file_path}")
      elsif File.directory?(entry)
        exclude_dirs.each do |x|
          Find.prune if (File.basename(entry) == x.strip)
        end
        # check to see if it is located in the target_path
        target_dir_path = "#{target_path}#{file_path}"
        if not File.directory?(target_dir_path)
          puts "Making Directory: #{target_dir_path}"
          FileUtils.mkdir_p(target_dir_path)
        end
      else
        puts 'Error'
      end
    end
  end
  
  def svn_calibration(message)
    IO.popen("svn status") do |pipe|
      while (line = pipe.gets)
        process_status_line(line)
      end
    end
    `svn commit -m 'READ ONLY: #{message}'`
  end
  
  def process_status_line(line)
    puts "Processing: #{line}"
    action_ch = line[0]
    file_name = line[7, line.length].strip
    
    # process action
    if (action_ch == 63) # Looking for ?
      puts "Adding: #{file_name}"
      `svn add #{file_name}`
    elsif (action_ch == 33) # Looking for !
      puts "Deleting: #{file_name}"
      `svn rm --force #{file_name}`
    else
      puts "Ignoring: #{action_ch} #{line}"
    end
  end
  
end
app = Git2Svn.new(ARGV,STDIN)
app.run
