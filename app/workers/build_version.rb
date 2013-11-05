class BuildVersion
  include Sidekiq::Worker

  sidekiq_options queue: 'default', unique: true, retry: 2, failures: :exhausted

  def perform(bower_name, version)
    Rails.logger.info "Building #{bower_name}##{version}..."
    Build::Converter.run!(bower_name, version)
  end
end
