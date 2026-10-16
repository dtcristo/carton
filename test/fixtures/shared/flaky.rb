# frozen_string_literal: true

raise 'flaky import failed' if ENV['CARTON_FLAKY_FAIL']

export status: :loaded
