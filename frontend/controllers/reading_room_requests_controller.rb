class ReadingRoomRequestsController < ApplicationController

  RESOLVES = ['requested_item']

  include ApplicationHelper

  # TODO: review access controls for these endpoints
  set_access_control  "view_repository" => [:index, :show, :picking_slip, :set_status]

  def index
    params[:page] ||= 1
    response = JSONModel::HTTP.get_json('/reading_room_requests/search', params)
    response[:criteria] = params
    @search_data = SearchResultData.new(response)
  end

  def show
    @reading_room_request = JSONModel(:reading_room_request).find(params[:id], find_opts.merge('resolve[]' => RESOLVES))
  end

  def current_record
    @reading_room_request
  end

  def set_status
    response = JSONModel::HTTP.post_form("/reading_room_requests/#{params[:id]}/set_status", :status => params[:status])
    render :json => {:status => 'updated'}
  end

  java_import Java::org::apache::fop::apps::FopFactory
  java_import Java::org::apache::fop::apps::Fop
  java_import Java::org::apache::fop::apps::MimeConstants
  import javax.xml.transform.stream.StreamSource
  import javax.xml.transform.TransformerFactory
  import javax.xml.transform.sax.SAXResult

  def picking_slip
    @reading_room_request = JSONModel(:reading_room_request).find(
      params[:id],
      'resolve[]' => ['requested_item',
                      'requested_item::container',
                      'requested_item::controlling_record',
                      'requested_item::controlling_record_series',
                      'requested_item::responsible_agency'])

    report_fo = render_to_string(:partial => 'reading_room_requests/picking_slip.fo.erb').strip

    fo_file = ASUtils.tempfile("picking_slip_fo")
    fo_file.write(report_fo)
    fo_file.close

    output_pdf_file = java.io.File.createTempFile("picking_slip", "pdf")
    output_stream = java.io.FileOutputStream.new(output_pdf_file)

    begin
      input_stream = java.io.FileInputStream.new(fo_file.path)

      fopfac = FopFactory.newInstance
      fopfac.setBaseURL( File.join(ASUtils.find_base_directory, 'stylesheets') )
      fop = fopfac.newFop(MimeConstants::MIME_PDF, output_stream)
      transformer = TransformerFactory.newInstance.newTransformer()
      res = SAXResult.new(fop.getDefaultHandler)
      transformer.transform(StreamSource.new(input_stream), res)
    ensure
      output_stream.close
    end

    filename = "picking_slip.#{params[:id]}.pdf"

    respond_to do |format|
      format.all do
        fh = File.open(output_pdf_file.path, "r")
        self.headers["Content-type"] = "application/pdf"
        self.headers["Content-disposition"] = "attachment; filename=\"#{filename}\""
        self.response_body = Enumerator.new do |y|
          begin
            while chunk = fh.read(4096)
              y << chunk
            end
          ensure
            fh.close
            fo_file.unlink
          end
        end
      end
    end
  end
end
