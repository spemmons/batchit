namespace :batchit do

  desc 'ensure that all Batchit models have shadows and former ones do not'
  task sync_all_models: :environment do
    Batchit::Context.sync_all_models
  end

end
