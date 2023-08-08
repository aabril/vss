module commands

import os
import log
import time
import markdown
import internal.template
import internal.config

const default_template = 'layouts/index.html'

const defautl_static = 'static'

const default_index = 'index.md'

const default_dist = 'dist'

struct BuildCommand {
mut:
	config           config.Config
	logger           log.Log
	dist             string
	static_dir       string
	template_content string
	config_map       map[string]string
}

// new_build_cmd create new build command instance.
pub fn new_build_cmd(conf config.Config, logger log.Log) BuildCommand {
	return BuildCommand{
		config: conf
		logger: logger
		dist: commands.default_dist
		static_dir: commands.defautl_static
		config_map: conf.as_map()
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

fn (mut b BuildCommand) md2html(md_path string) ! {
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

// copy_static copy static files to dist
fn (b BuildCommand) copy_static() ! {
	if os.exists(b.static_dir) {
		os.cp_all(b.static_dir, b.dist, false)!
	}
}

// create_dist_dir create build output destination
fn (mut b BuildCommand) create_dist_dir() ! {
	if os.exists(b.dist) {
		b.logger.info('re-create dist dir')
		os.rmdir_all(b.dist)!
		os.mkdir_all(b.dist)!
	} else {
		b.logger.info('create dist dir')
		os.mkdir_all(b.dist)!
	}
}

fn (mut b BuildCommand) is_ignore(path string) bool {
	// e.g. README.md
	file_name := os.file_name(path)
	// notify user that build was skipped
	if file_name in b.config.build.ignore_files {
		return true
	}
	return false
}

fn (mut b BuildCommand) set_base_url(url string) {
	b.config.base_url = url
	b.config_map['base_url'] = url
}

// run build command main process
pub fn (mut b BuildCommand) run() ! {
	println('Start building')
	mut sw := time.new_stopwatch()
	template_content := os.read_file(commands.default_template)!
	b.template_content = template_content

	b.create_dist_dir()!
	// copy static dir files
	b.logger.info('copy static files')
	b.copy_static()!

	mds := normalise_paths(os.walk_ext('.', '.md'))
	b.logger.info('start md to html')
	for path in mds {
		if b.is_ignore(path) {
			b.logger.info('${path} is included in ignore_files, skip build')
			continue
		}
		b.md2html(path)!
	}
	b.logger.info('end md to html')

	sw.stop()
	println('Total in ' + sw.elapsed().milliseconds().str() + ' ms')
	return
}
