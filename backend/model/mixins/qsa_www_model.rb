require_relative '../public_db'

module QSAWWWModel
  def self.included(base)
    base.extend(ClassMethods)

    if base.ancestors.include?(ASModel)
      base.include(ASModelCompat)
    end
  end

  module ClassMethods
    def qsa_www_table(table_sym)
      qsa_www_model_clz = self

      PublicDB.connected_hook do
        qsa_www_model_clz.set_dataset(PublicDB.pool[table_sym])
      end
    end
  end

end
