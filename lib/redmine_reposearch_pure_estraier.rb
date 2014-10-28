require "redmine_reposearch"
include RedmineReposearch
require "estraierpure"
include EstraierPure
require "yaml"
include YAML

require 'pathname'

module RedmineReposearchPureEstraier

  class RedmineReposearchPureEstraierBackend < RedmineRepoSearchBackend
    @@Config = YAML.load_file("%s/config/hyperestraier-configuration.yml" % File.join(Rails.root.to_s,'plugins',File.dirname(__FILE__).gsub(File.join(Rails.root.to_s,'plugins'),'').split("/")[1]))[Rails.env]

    attr_accessor :node

    def open(mode)
      @node = Node::new
      @node.set_url(@@Config["hyperestraier"]["url"])
      @node.set_auth(@@Config["hyperestraier"]["username"], @@Config["hyperestraier"]["password"])
    end

    def close

    end

    def remove

    end

    def delete_doc(uri)
      id = @node.uri_to_id(uri)
      return nil if id == nil
      Rails.logger.info("Delete doc: %s (%s)" % [uri, id])
      return @node.out_doc(id)
    end

    def get_doc(uri)
      id = @node.uri_to_id(uri)
      return nil if id == nil
      Rails.logger.info("Get doc: %s (%s)" % [uri, id])
      return @node.get_doc(id)
    end

    def get_text(repository , identifier , entry , uri)
      
      text = repository.cat(entry.path, identifier)
      Rails.logger.info("text:nil") if !text

      path = Pathname.new(URI.escape(entry.path))

      Rails.logger.info("path: %s %s %s" % [ path.to_s , path.basename.to_s  , path.extname.to_s ] )

      File.binwrite("/tmp/#{path.basename}",text)

      html2text = Setting.plugin_redmine_reposearch['html2text']
#      File.binwrite("/tmp/redminereposearch#{path.extname}",text)
      case path.extname
      when ".pdf" then
        pdf2txt = Setting.plugin_redmine_reposearch['pdf2txt']

        pp = "#{pdf2txt} '/tmp/#{path.basename}'" + (Setting.plugin_redmine_reposearch['pdf2html'] ? " | #{html2text}":"")
        
        Rails.logger.info("pp: %s" % [ pp ] )

        oo = IO.popen(pp,'r+')
        text = oo.read
#        text = "pdf pdf pdf"
#        Rails.logger.info("pdf: %s" % [ text ] )
        oo.close
 
      when ".doc" then 
        doc2txt = Setting.plugin_redmine_reposearch['doc2txt']

        pp = "#{doc2txt} '/tmp/#{path.basename}'" + (Setting.plugin_redmine_reposearch['pdf2html'] ? " | #{html2text}":"")

        oo = IO.popen(pp,'r+')
        text = oo.read
#        Rails.logger.info("doc: %s" % [ text ] )
        oo.close

#        Rails.logger.info("text: %s" % [ text ] )
      when ".ppt" then 
        ppt2txt = Setting.plugin_redmine_reposearch['ppt2txt']

        pp = "#{ppt2txt} '/tmp/#{path.basename}'" + (Setting.plugin_redmine_reposearch['pdf2html'] ? " | #{html2text}":"")

        oo = IO.popen(pp,'r+')
        text = oo.read
#        Rails.logger.info("ppt: %s" % [ text ] )
        oo.close

#        Rails.logger.info("text: %s" % [ text ] )

      when ".xls" then 
        xls2txt = Setting.plugin_redmine_reposearch['xls2txt']

        pp = "#{xls2txt} '/tmp/#{path.basename}'" + (Setting.plugin_redmine_reposearch['pdf2html'] ? " | #{html2text}":"")

        oo = IO.popen(pp,'r+')
        text = oo.read
#        Rails.logger.info("xls: %s" % [ text ] )
        oo.close

#        Rails.logger.info("text: %s" % [ text ] )

      else
        oo = IO.popen("/usr/bin/nkf -w '/tmp/#{path.basename}'",'r+')
        text = oo.read
        oo.close
#        Rails.logger.info("text: %s" % [ text ] )
      end

      File.delete("/tmp/#{path.basename}")

      return text
    end

    def add_or_update_index(repository, identifier, entry, uri)
      text = get_text(repository , identifier , entry , uri)
#     text = repository.cat(entry.path, identifier)
      Rails.logger.info("entry_path: %s" % entry.path)
      return delete_doc(uri) unless text

      doc = get_doc(uri)
      if not doc or delete_doc(uri)
        Rails.logger.info("Add doc: %s" % uri)
        doc = EstraierPure::Document.new
        doc.add_attr('@uri', uri)
        doc.add_attr('@title', URI.escape(entry.path))
        doc.add_attr('@repository', (repository.identifier or MAIN_REPOSITORY_IDENTIFIER))
        doc.add_attr('@rev', identifier)
        content_type = Redmine::MimeType.of(entry.path)
        doc.add_attr('@content_type', content_type) if content_type

        doc.add_text(text)
        result = @node.put_doc(doc)
      end
    end

    def optimize
      @node.optimize
    end

    def search(query, repository, rev, content_type=nil)
      condition = Condition.new
      condition.set_phrase(query)
      Rails.logger.info("Search conditions: %s, %s, %s" % [
          repository, rev, content_type])
      condition.add_attr("@repository STREQ %s" % repository) if repository
      condition.add_attr("@rev STREQ %s" % rev) if rev
      condition.add_attr("@content_type STREQ %s" % content_type) if content_type
      return @node.search(condition,0)
    end
  end
end
