#!/usr/bin/env ruby

=begin
module for storing metadata
=end

require 'mongo'

module Store
  class MongoStore
    def initialize(host, port, db, coll)
      @host = host
      @port = port
      @db = db
      @coll = coll
      @mongo_client = Mongo::Client.new([ "#{@host}:#{@port}" ], :database => "#{@db}")
    end

    def insertdoc(doc)
      @mongo_client[@coll].insert_one(doc)
    end

    def checkrecord(rec_id)
      res = @mongo_client[@coll].find(:_id=>rec_id).entries.length > 0
      return res
    end
  end
end