require_relative '../public_db'

module QSAWWWModel
  def self.included(base)
    base.extend(ClassMethods)

    if base.ancestors.include?(ASModel)
      base.include(ASModelCompat)
      base.external_system_name = 'QSA Public'
    end
  end

  module ClassMethods
    def qsa_www_table(table_sym)
      qsa_www_model_clz = self

      PublicDB.connected_hook do
        if PublicDB.pool.nil?
          raise "DATABASE ERROR: Could not connect to Public database"
        end

        qsa_www_model_clz.set_dataset(PublicDB.pool[table_sym])
      end
    end
  end

end
