module EncoderProjects
  class CatalogueSummaryImport
    def self.call(record, candidate)
      record.with_lock do
        if eligible?(record, candidate)
          reviewed = candidate.merge('previous_abstract' => record.abstract, 'replace_external_abstract' => true)
          SummaryImport.new(candidate: reviewed, parameters: {}).call(record, candidate['abstract'])
        end
      end
      record
    end

    def self.eligible?(record, candidate)
      if record.abstract_protected? || candidate['abstract'].blank? || record.abstract == candidate['abstract']
        return false
      end

      incoming = candidate['abstract_source'] || candidate['source']
      SynopsisPreference.rank(incoming) <= SynopsisPreference.rank(record.abstract_provenance['source'])
    end
  end
end
