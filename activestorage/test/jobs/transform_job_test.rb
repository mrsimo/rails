# frozen_string_literal: true

require "test_helper"

class ActiveStorage::TransformJobTest < ActiveJob::TestCase
  setup do
    @blob = create_file_blob
    @was_variable_content_types = ActiveStorage.variable_content_types
    @was_variant_transformer = ActiveStorage.variant_transformer
    ActiveStorage.variable_content_types = %w(image/jpeg image/png)
    ActiveStorage.variant_transformer = ActiveStorage::Transformers::ImageMagick
  end

  teardown do
    ActiveStorage.variable_content_types = @was_variable_content_types
    ActiveStorage.variant_transformer = @was_variant_transformer
  end

  test "creates variant" do
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @blob.variant(transformations).send(:processed?) }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @blob, transformations
      end
    end
  end

  test "creates variant for previewable file" do
    analyze_with("ImageAnalyzer::Vips") do
      preview_with("PopplerPDFPreviewer") do
        @blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
        transformations = { resize_to_limit: [100, 100] }

        assert_changes -> { @blob.preview(transformations).send(:processed?) }, from: false, to: true do
          perform_enqueued_jobs do
            ActiveStorage::TransformJob.perform_later @blob, transformations
          end
          @blob.reload
        end

        assert @blob.preview(transformations).image.variant(transformations).send(:processed?)
      end
    end
  end

  test "creates variant when untracked" do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, false
    transformations = { resize_to_limit: [100, 100] }

    begin
      assert_changes -> { @blob.variant(transformations).send(:processed?) }, from: false, to: true do
        perform_enqueued_jobs do
          ActiveStorage::TransformJob.perform_later @blob, transformations
        end
      end
    ensure
      ActiveStorage.track_variants = @was_tracking
    end
  end

  test "ignores unrepresentable blob" do
    unrepresentable_blob = create_blob(content_type: "text/plain")
    transformations = { resize_to_limit: [100, 100] }

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::TransformJob.perform_later unrepresentable_blob, transformations
      end
    end
  end
end
