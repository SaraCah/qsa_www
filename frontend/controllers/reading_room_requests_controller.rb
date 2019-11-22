class ReadingRoomRequestsController < ApplicationController

  RESOLVES = ['requested_item']

  SORT_COLUMNS = [
                  'qsa_id_u_sort',
                  'rrr_requested_item_qsa_id_u_sort',
                  'rrr_requested_item_availability_u_ssort',
                  'rrr_requesting_user_u_ssort',
                  'rrr_status_u_ssort',
                  'rrr_date_required_u_ssortdate',
                 ]

  include ApplicationHelper

  # TODO: review access controls for these endpoints
  set_access_control  "view_repository" => [:index, :show, :picking_slip, :set_status, :bulk_set_status]

  def index
    criteria = params.to_hash

    # added this to allow for poking into @search_data.sort_fields - obscure huh?
    criteria['type[]'] = ['reading_room_request']

    criteria['page'] ||= '1'
    criteria['page_size'] = '30'
    criteria['facet[]'] = Plugins.search_facets_for_type(:reading_room_request)
    if params['filter_term']
      criteria['filter_term[]'] = params['filter_term']
    end

    criteria['sort'] ||= 'user_mtime desc'

    if criteria['filter_term[]']
      if date_required_term = criteria['filter_term[]'].find {|term| JSON.parse(term).keys[0] == 'date_required'}
        criteria['filter_term[]'].delete(date_required_term)

        date_required = JSON.parse(date_required_term).values[0]
      end
    end

    if date_required
      start_date, end_date = [Date.today, Date.today + date_required].sort

      query = {'query' => {
                 'jsonmodel_type' => 'boolean_query',
                 'op' => 'AND',
                 'subqueries' => [
                   {
                     'jsonmodel_type' => 'date_field_query',
                     'comparator' => 'greater_than',
                     'field' => 'rrr_date_required_u_ssortdate',
                     'value' => "%sT00:00:00Z" % [start_date.iso8601],
                   },
                   {
                     'jsonmodel_type' => 'date_field_query',
                     'comparator' => 'lesser_than',
                     'field' => 'rrr_date_required_u_ssortdate',
                     'value' => "%sT00:00:00Z" % [end_date.iso8601],
                   }
                 ]
               }
              }

      criteria['filter'] = JSONModel(:advanced_query).from_hash(query).to_json
    end

    Search.build_filters(criteria)

    response = JSONModel::HTTP.get_json('/reading_room_requests/search', params_for_backend_search.merge(criteria))
    response ||= {'results' => [], 'facets' => {'facet_fields' => []}}
    response[:criteria] = criteria

    # If we dropped the filter_term out, add it back so the results page looks right.
    if date_required_term
      response[:criteria]['filter_term[]'] << date_required_term
    end

    @search_data = SearchResultData.new(response)

    SORT_COLUMNS.each do |col|
      @search_data.sort_fields << col
    end

    @rrr_sort_columns = SORT_COLUMNS
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

  def bulk_set_status
    response = JSONModel::HTTP.post_form("/reading_room_requests/bulk_set_status", :status => params[:status], :ids => params[:ids])
    render :json => {:status => 'updated'}
  end

  java_import Java::org::apache::fop::apps::FopFactory
  java_import Java::org::apache::fop::apps::Fop
  java_import Java::org::apache::fop::apps::MimeConstants
  import javax.xml.transform.stream.StreamSource
  import javax.xml.transform.TransformerFactory
  import javax.xml.transform.sax.SAXResult

  def picking_slip
    @reading_room_requests = JSONModel::HTTP.get_json('/reading_room_requests/batch',
      'ids' => params[:ids],
      'resolve[]' => ['requested_item',
                      'requested_item::container',
                      'requested_item::container::container_locations',
                      'requested_item::controlling_record',
                      'requested_item::controlling_record::parent',
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

  def self.status_button_map
    @status_button_map ||= {
      'PENDING' => {:style => 'default', :label => 'Pending'},
      'AWAITING_AGENCY_APPROVAL' => {:style => 'warning', :label => 'Awaiting Agency Approval'},
      'APPROVED_BY_AGENCY' => {:style => 'success', :label => 'Approved by Agency'},
      'REJECTED_BY_AGENCY' => {:style => 'danger', :label => 'Rejected by Agency'},
      'CANCELLED_BY_QSA' => {:style => 'danger', :label => 'Cancelled by QSA'},
      'CANCELLED_BY_RESEARCHER' => {:style => 'danger', :label => 'Cancelled by Researcher'},
      'BEING_RETRIEVED' => {:style => 'info', :label => 'Being Retrieved'},
      'DELIVERED_TO_READING_ROOM' => {:style => 'primary', :label => 'Delivered to Reading Room'},
      'DELIVERED_TO_ARCHIVIST' => {:style => 'primary', :label => 'Delivered to Archivist'},
      'DELIVERED_TO_CONSERVATION' => {:style => 'primary', :label => 'Delivered to Conservation'},
      'COMPLETE' => {:style => 'success', :label => 'Returned to Home Location'},
    }
  end


  helper_method :status_label
  def status_label(status)
    button = self.class.status_button_map[status]
    "<span class=\"label label-#{button[:style]}\">#{button[:label]}</span>".html_safe
  end


  def self.status_workflow_map
    @status_workflow_map ||= {
      'AWAITING_AGENCY_APPROVAL' =>
      [
       'APPROVED_BY_AGENCY',
       'REJECTED_BY_AGENCY',
       'CANCELLED_BY_QSA',
       'CANCELLED_BY_RESEARCHER',
      ],
      'PENDING' =>
      [
       'BEING_RETRIEVED',
       'CANCELLED_BY_QSA',
       'CANCELLED_BY_RESEARCHER',
      ],
      'BEING_RETRIEVED' =>
      [
       'DELIVERED_TO_CONSERVATION',
       'DELIVERED_TO_ARCHIVIST',
       'DELIVERED_TO_READING_ROOM',
       'CANCELLED_BY_QSA',
       'CANCELLED_BY_RESEARCHER',
      ],
      'BEING_RETRIEVED_RESTRICTED' =>
      [
       'DELIVERED_TO_CONSERVATION',
       'DELIVERED_TO_ARCHIVIST',
       'CANCELLED_BY_QSA',
       'CANCELLED_BY_RESEARCHER',
      ],
      'DELIVERED_TO_CONSERVATION' =>
      [
       'DELIVERED_TO_ARCHIVIST',
       'DELIVERED_TO_READING_ROOM',
      ],
      'DELIVERED_TO_CONSERVATION_RESTRICTED' =>
      [
       'DELIVERED_TO_ARCHIVIST',
      ],
      'DELIVERED_TO_READING_ROOM' =>
      [
       'COMPLETE',
      ],
      'DELIVERED_TO_ARCHIVIST' =>
      [
       'COMPLETE',
      ],
    }
  end


  def status_workflow(status, restricted)
    key = (restricted && self.class.status_workflow_map.has_key?(status + '_RESTRICTED')) ? status + '_RESTRICTED' : status
    self.class.status_workflow_map.fetch(key, [])
  end

  def status_button(status, id, opts = {})
    btn_def = self.class.status_button_map[status]
    btn_size = opts[:full_size] ? 'btn-sm' : 'btn-xs'
    "<button class=\"btn btn-#{btn_def[:style]} #{btn_size} rrr-status rrr-status-#{status}\" data-id=\"#{id}\" data-status=\"#{status}\">#{btn_def[:label]}</button>".html_safe
  end

  helper_method :buttons_for_request
  def buttons_for_request(status, id, opts = {})
    opts[:restricted] ||= :unrestricted
    full_size = !!opts[:full_size]
    status = status.upcase
    buttons = []
    if [:unrestricted, :both].include?(opts[:restricted])
      buttons += status_workflow(status, false)
    end
    if [:restricted, :both].include?(opts[:restricted])
      buttons += status_workflow(status, true)
    end

    # stoopid reversing to keep cancel buttons at the end
    buttons = buttons.reverse.uniq.reverse

    buttons.map{|button| status_button(button, id, :full_size => full_size)}
  end
end
