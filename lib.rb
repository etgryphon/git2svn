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
# (1) ./git2svn <path to git dir or file> <svn repo address> [--file=name] [--ignore=ignore list comma seperated] [--save=name] [--msg="svn message"]
#     Examples: 
#       => ./git2svn ~/gitrepos/myrepo/ http://my.svn.repo/directory/
#       => ./git2svn ~/gitrepos/myrepo/ http://my.svn.repo/directory/ --message="my message" --ignore==.svn,.git,public,log
#       => ./git2svn ~/gitrepos/myrepo/myfile http://my.svn.repo/directory/ --file=myfile --msg="my message" --ignore==.svn,.git,public,log
#       => ./git2svn ~/gitrepos/myrepo/myfile http://my.svn.repo/directory/ --file=myfile --msg="my message" --ignore==.svn,.git,public,log --save=standard
# (2) ./git2svn --use=<name> [--message="svn message"]
#
# == Author
# Evin Grano, Mike Ball
#
# == Copyright
#   Copyright (c) 2008-2011 Evin Grano, Mike Ball. All Rights Rserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'find'
require 'fileutils'
require 'digest/sha1'
# ***********************************************************
# Usages:
# 

class Git2Svn

  def initialize(arguments, stdin)
    @valid_args = [:file, :ignore, :msg, :save, :use]
    # Check to make sure this has the minimum
    if arguments.length < 2
      puts "ERROR: Must have at least a 2 arguments and you have #{arguments.length}" 
      return 
    end
    @config = {:valid_config => false, :ignore => '.svn,.git,public,log,tmp,temp', :msg => 'New Stuff'}
    # grab the GIT path
    @config[:git_path] = arguments.shift
    return unless validate_git_path(@config[:git_path])
    # grab svn path
    @config[:svn_repo] = arguments.shift
    return unless validate_svn(@config[:svn_repo])
    # get all the arguments off
    arguments.each{ |x| parse_argument(x) }
    @config[:valid_config] = true
  end
  
  def validate_git_path(path)
    if File.file?(path)
      puts "#{path} => is a File"
      @config[:is_file] = true
      return true
    elsif File.directory?(path) 
      puts "#{path} => is a Directory"
      @config[:is_dir] = true
      return true
    else
      puts "ERROR: git path is NOT a directory or file that exists..."
      return false
    end
  end
  
  def validate_svn(path)
    # TODO: [EG] validate that this is a valid svn address
    return true
  end
  
  def parse_argument(arg)
    parg = arg.split('=')
    if (parg && parg.length == 2)
      type = parg[0][2..-1].to_sym
      if @valid_args.include?(type)
        val = @config[type] ? @config[type] + parg[1] : parg[1]
        @config[type] = val
      else
        puts "WARN: ignoring argument [#{arg}] because it is invalid"
      end
    else
      puts "bad argument"
    end
  end
  
  def run
    return unless @config[:valid_config]
    
    # TODO: Create a temp SVN Directory to checkout the latest copy of the SVN repository
    FileUtils.mkdir_p "./.tmp_g2s/"
    
    # Change to the SVN Root directory and get the latest to correct collisions
    sha1 = Digest::SHA1.hexdigest("x#{@config[:git_path]}+#{@config[:svn_repo]}]")
    Dir.chdir('./.tmp_g2s')
    svn_path = "./#{sha1}"
    if (File.directory?(svn_path))
      Dir.chdir(svn_path)
      puts "UPDATING: svn repo #{@config[:svn_repo]}..."
      `svn update`
    else
      puts "CREATE: new tmp svn repo #{@config[:svn_repo]}..."
      `svn co #{@config[:svn_repo]} #{sha1}`
    end
    puts "... FINISHED!"
    
    
    puts 'Search and Destroy';
    excludes = @config[:ignore].split(',').uniq
    puts "testing: #{excludes}"
    search_and_destroy(svn_path+'/', excludes)
    #   
    # # Copy all files from GIT to SVN
    # traverse_and_copy(@config[:git_path], svn_path+'/', excludes) 
    # 
    # # Calibrate the SVN repo to the new changes
    # # TODO:  Add the ability to grab the latest commit message from GIT
    # svn_calibration(@config[:msg])
    
  end
  
  protected   
  def search_and_destroy(src_path, exclude_dirs)
    puts "I am here: #{FileUtils.pwd}"
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
