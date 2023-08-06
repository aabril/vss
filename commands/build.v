module commands

import os
import cli
import log
import time
import markdown
import internal.template
import internal.config

const default_config = 'config.toml'

const default_template = 'layouts/index.html'

const defautl_static = 'static'

const default_index = 'index.md'

const default_dist = 'dist'

struct Builder {
mut:
	config           config.Config
	logger           log.Log
	dist             string
	static_dir       string
	template_content string
	config_map       map[string]string
}

fn new_builder(logger log.Log) Builder {
	return Builder{
		logger: logger
		dist: commands.default_dist
		static_dir: commands.defautl_static
	}
}

// new_build_cmd returns a cli.Command for build command
pub fn new_build_cmd() cli.Command {
	return cli.Command{
		name: 'build'
		description: 'build your site'
		usage: 'vss build'
		execute: fn (cmd cli.Command) ! {
			mut logger := log.Log{}
			logger.set_level(log.Level.info)
			conf := load_config(commands.default_config)!
			build(conf, mut logger) or {
				logger.error(err.msg())
				println('Build failed')
			}
		}
	}
}

fn get_html_path(md_path string) string {
	mut file_name := os.file_name(md_path)
	file_name = file_name.replace('.md', '.html')
	dir := os.dir(md_path)
	if dir == '.' {
		return file_name
	}

	return os.join_path(dir, file_name)
}

fn normalise_paths(paths []string) []string {
	cwd := os.getwd() + os.path_separator
	mut res := paths.map(os.abs_path(it).replace(cwd, '').replace(os.path_separator, '/'))
	res.sort()
	return res
}

fn get_md_content(path string) !string {
	return os.read_file(path)!
}

fn get_content(path string) !string {
	md := get_md_content(path)!
	return markdown.to_html(md)
}

fn check_layout(path string) bool {
	// check if layout is specified in front matter
	// if not, use default layout
	// if specified, check if layout file exists
	// if not, return error
	return true
}

fn (mut b Builder) md2html(md_path string) ! {
	// get html body content from md
	b.logger.info('start md to html: ${md_path}')
	content := get_content(md_path)!
	// want to change from contents to content
	b.config_map['contents'] = content

	// parse template
	html_path := get_html_path(md_path)
	dir := os.dir(md_path)
	mut template_content := ''
	if os.exists('layouts/${html_path}') {
		b.logger.info('use custom template: layouts/${html_path}')
		template_content = os.read_file('layouts/${html_path}')!
	} else if os.exists('layouts/${dir}/index.html') {
		b.logger.info('use custom template: layouts/${dir}/index.html')
		template_content = os.read_file('layouts/${dir}/index.html')!
	} else {
		b.logger.info('use default template')
		template_content = b.template_content
	}

	html := template.parse(template_content, b.config_map)
	dist_path := os.join_path(b.dist, html_path)
	if !os.exists(os.dir(dist_path)) {
		os.mkdir_all(os.dir(dist_path))!
	}
	os.write_file(dist_path, html)!
}

// load_config loads a toml config file
fn load_config(toml_file string) !config.Config {
	toml_text := os.read_file(toml_file)!
	return config.load(toml_text)
}

// copy_static copy static files to dist
fn (b Builder) copy_static() ! {
	if os.exists(b.static_dir) {
		os.cp_all(b.static_dir, b.dist, false)!
	}
}

// create_dist_dir create build output destination
fn (mut b Builder) create_dist_dir() ! {
	if os.exists(b.dist) {
		b.logger.info('re-create dist dir')
		os.rmdir_all(b.dist)!
		os.mkdir_all(b.dist)!
	} else {
		b.logger.info('create dist dir')
		os.mkdir_all(b.dist)!
	}
}

fn (mut b Builder) is_ignore(path string) bool {
	// e.g. README.md
	file_name := os.file_name(path)
	// notify user that build was skipped
	if file_name in b.config.build.ignore_files {
		return true
	}
	return false
}

fn build(conf config.Config, mut logger log.Log) ! {
	println('Start building')
	mut sw := time.new_stopwatch()
	mut b := new_builder(logger)
	template_content := os.read_file(commands.default_template)!
	b.template_content = template_content
	b.config = conf
	b.config_map = conf.as_map()

	b.create_dist_dir()!
	// copy static dir files
	logger.info('copy static files')
	b.copy_static()!

	mds := normalise_paths(os.walk_ext('.', '.md'))
	logger.info('start md to html')
	for path in mds {
		if b.is_ignore(path) {
			logger.info('${path} is included in ignore_files, skip build')
			continue
		}
		b.md2html(path)!
	}
	logger.info('end md to html')

	sw.stop()
	println('Total in ' + sw.elapsed().milliseconds().str() + ' ms')
	return
}
