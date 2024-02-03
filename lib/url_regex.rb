class UrlRegex
  URL_REGEX_STRING = '((?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:\'".,<>?«»“”‘’]))'.freeze

  def self.for_matching_url
    /\A#{URL_REGEX_STRING}\z/
  end

  def self.for_finding_urls
    /#{URL_REGEX_STRING}/
  end
end
