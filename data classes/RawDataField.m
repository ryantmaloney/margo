classdef RawDataField < dynamicprops
% class definition for raw data maps container

    properties
        raw;
        path;
        fID;
        dim;
        precision;
    end

    properties(Hidden = true)
        Parent;
    end

    methods
        function obj = RawDataField(varargin)

            % set default values
            obj.raw = RawDataMap;
            obj.path = '';
            obj.precision = 'single';
            obj.dim = 0;
            obj.fID = -1;
            obj.Parent = [];

            % parse and assign variable inputs
            for i=1:length(varargin)
                if ischar(varargin{i})
                    switch varargin{i}
                        case 'Path'
                            i = i+1;
                            obj.path = varargin{i};
                        case 'Dim'
                            i = i+1;
                            obj.dim = varargin{i};
                        case 'Precision'
                            i = i+1;
                            obj.precision = varargin{i};
                        case 'fID'
                            i = i+1;
                            obj.fID = varargin{i};
                        case 'Parent'
                            i = i+1;
                            obj.Parent = varargin{i};
                    end
                end
            end

        end


        % initialize raw data memmap from raw data file
        function obj = attach(obj)


            % intialize raw map parent
            obj.raw.Parent = obj;
            field_name = get_field_name(obj);

            % try to attach the raw data file
            try

                if ~isfield(obj.Parent.meta,'num_traces')
                    obj.Parent.meta.num_traces = ...
                        sum(obj.Parent.meta.roi.num_traces);
                end
                if ~isfield(obj.Parent.meta,'num_frames') ||...
                    obj.Parent.meta.num_frames < 2

                    obj.Parent.meta.num_frames = get_n_frames(obj);
                end

                % ensure correct dimensions
                ntrace = obj.Parent.meta.num_traces;
                nframe = obj.Parent.meta.num_frames;
                obj.dim(obj.dim==1)=[];
                if isempty(obj.dim)
                    obj.dim = [nframe 1];

                elseif numel(obj.dim)==1 && obj.dim == nframe
                    obj.dim = [nframe 1];

                elseif (any(obj.dim == ntrace) &&...
                        obj.dim(end) ~= ntrace) || ...
                        ~any(obj.dim == nframe) || ...
                        (strcmpi(field_name,'centroid') && ~any(obj.dim == ntrace))

                    tmp_dim = obj.dim;
                    tmp_dim(find(obj.dim==ntrace,1))=[];
                    tmp_dim(find(obj.dim==nframe,1))=[];
                    obj.dim = [nframe tmp_dim ntrace];
                end

                if exist(obj.path,'file')==2

                    % get expected file size
                    bytes_per = bytes_per_el(obj.precision);
                    exp_sz = prod(obj.dim)*bytes_per;

                    fInfo = dir(obj.path);
                    if ~fInfo(1).bytes
                        return
                    elseif fInfo(1).bytes ~= exp_sz

                        % check to see if reducing frame number
                        % by one matches expected size
                        new_dim = obj.dim;
                        new_dim(new_dim==nframe)=nframe-1;
                        if prod(new_dim)*bytes_per == fInfo(1).bytes
                            obj.Parent.meta.num_frames = nframe-1;
                            obj.dim(obj.dim==nframe)=nframe-1;

                        % else check if file size is larger than
                        % expected size by a whole number
                        elseif fInfo(1).bytes/exp_sz == uint64(fInfo(1).bytes/exp_sz)

                            new_bytes_per = fInfo(1).bytes/exp_sz * bytes_per;
                        % else check if file size is smaller than
                        % expected size by a whole number
                        elseif exp_sz/fInfo(1).bytes == uint64(exp_sz/fInfo(1).bytes)
                            new_bytes_per = exp_sz/fInfo(1).bytes * bytes_per;
                        end

                        % assign a default precision
                        if exist('new_bytes_per','var')
                            warning(sprintf(['Binary %s file size did not match expected'...
                                ' file size. Attempting to automatically ajust'...
                                ' the data precision. Resulting raw data may '...
                                'be inaccurate.'],field_name));
                            switch new_bytes_per
                                case 1
                                   obj.precision = 'uint8';
                                case 2
                                    obj.precision = 'uint16';
                                case 4
                                    obj.precision = 'single';
                                case 8
                                    obj.precision = 'double';
                                otherwise
                                    obj.precision = sprintf('ubit%i',new_bytes_per*8);
                            end
                        end
                    end

                    prcn = obj.precision;
                    if any(strcmpi({'logical';'ubit1';'bit1'},prcn))
                        attach_binary(obj);
                    else
                        obj.raw.map = memmapfile(obj.path,...
                            'Format',{prcn,fliplr(obj.dim),'raw'});
                    end

                    % resize if necessary
                    sz = size(obj.raw.map.Data);
                    if any(sz>1)
                        frame_num = sz(sz>1);
                        obj.dim = [frame_num obj.dim];
                        obj.raw.map = memmapfile(obj.path, ...
                            'Format',{obj.precision,fliplr(obj.dim),'raw'});
                    end
                end

            catch
                % try to automatically repair the file path
                try
                    p = obj.Parent.meta.path;
                    updatepaths(obj.Parent,[p.dir p.name],false);
                    obj.raw.map = memmapfile(obj.path, ...
                                'Format',{obj.precision,fliplr(obj.dim),'raw'});
                catch ME
                    switch ME.identifier
                        case 'MATLAB:memmapfile:inaccessibleFile'
                            error(['Failed to initialize %s raw data map. '...
                                'No such file or directory:\n'...
                                '\t%s'],field_name,obj.path);
                    end
                end
            end
            if ~isattached(obj)
                warning(sprintf(['failed to attach %s raw data map, '...
                    'automatic raw data file path repair failed'],field_name));
            end

        end

        function obj = detach(obj)
            if strcmpi(obj.precision,'logical')
                try
                    fclose(obj.fID);
                catch
                end
            end
            obj.raw.map = [];
        end

        function obj = reset(obj)
            detach(obj);
            attach(obj);
        end

        function obj = attach_binary(obj)

            obj.fID = fopen(obj.path,'r');
            if obj.fID ~= -1
                dimensions = fliplr(obj.dim);
                obj.raw.map.Data.raw = ...
                    fread(obj.fID,prod(dimensions),'ubit1=>logical');
                obj.raw.map.Data.raw = reshape(obj.raw.map.Data.raw,dimensions);
                obj.raw.map.Format = {'logical'};
            else
                error('invalid fileID');
            end

        end

        function name = get_field_name(obj)
            [~,filename,~] = fileparts(obj.path);
            name = filename(strfind(filename,'__')+2:end);
        end

        function out = isattached(obj)
            try
                out = ~any(~size(obj.raw));
            catch
                out = false;
            end
        end

        function out  = size(obj)
            out = obj.dim;
            if numel(out) == 1
                out = [out 1];
            end
        end

        % automatically query frame number from raw data
        function out = get_n_frames(obj)

            time = obj.Parent.data.time;
            if exist(time.path,'file')==2
                time_info = dir(time.path);
                f_size = time_info.bytes;
                bytes_per = bytes_per_el(time.precision);
                out = f_size/bytes_per;
            else
                warning(['could not automatically repair frame number'...
                    'from time raw data file, file not found']);
            end
        end

        function addprops(obj,props)

            if ~iscell(props)
                props = {props};
            end

            % remove pre-existing properties from list
            exclude = cellfun(@(p) isprop(obj,p), props);
            props(exclude) = [];

            % initialize new properties
            if ~isempty(props)
                cellfun(@(p) addprop(obj,p), props, 'UniformOutput', false);
            end

        end

        function export_to_csv(obj)

            % assigned format_spec
            unsigned_int = {'logical';'uint8';'uint16';'uint32';'uint64'};
            signed_int = {'int8','int16','int32','int64'};
            floating_pt = {'single','double'};
            if any(strcmp(unsigned_int,obj.precision))
                format_spec = '%u,';
            elseif any(strcmp(signed_int,obj.precision))
                format_spec = '%i,';
            elseif any(strcmp(floating_pt,obj.precision))
                format_spec = '%0.6f,';
            end

            % scale format spec up to length of row and insert newline
            format_spec = repmat(format_spec,1,obj.dim(end));
            format_spec = [format_spec(1:end-1) char(10)];
            fID = batch_to_csv(obj, format_spec);

        end
    end
end


% exports raw data files to csv in batches
function fID = batch_to_csv(obj, format_spec)

    [csv_dir,csv_name,~] = fileparts(obj.path);
    field = csv_name(find(csv_name=='_',1,'Last')+1:end);
    reset(obj);
    [frames_per_batch, nbatches] = get_batch_sizes(obj.raw);

    % write data in batches
    sz = size(obj.raw);
    switch field
        % proceess x,y separately since centroid is 3 dimensional
        case 'centroid'
            fID(1) = fopen([csv_dir '/' csv_name '_x.csv'],'W');
            fID(2) = fopen([csv_dir '/' csv_name '_y.csv'],'W');

            % generate headers
            n = obj.Parent.meta.num_traces;
            headx = arrayfun(@(i) sprintf('centroid-%i-x',i), 1:n,...
                    'UniformOutput', false);
            heady = arrayfun(@(i) sprintf('centroid-%i-y',i), 1:n,...
                    'UniformOutput', false);
            hfs = repmat('%s,',1,sz(3));
            hfs(end) = char(10);

            fprintf(fID(1), hfs, headx{:});
            fprintf(fID(2), hfs, heady{:});


            for i=1:nbatches
                idx = [(i-1)*frames_per_batch+1 i*frames_per_batch];
                if idx(2) > sz(1)
                    batch_dat_x = obj.raw(idx(1):sz(1),1,:);
                    batch_dat_y = obj.raw(idx(1):sz(1),1,:);
                else
                    batch_dat_x = obj.raw(idx(1):idx(2),1,:);
                    batch_dat_y = obj.raw(idx(1):idx(2),2,:);
                end
                fprintf(fID(1), format_spec, batch_dat_x');
                fprintf(fID(2), format_spec, batch_dat_y');
                reset(obj);
            end
        otherwise
            fID = fopen([csv_dir '/' csv_name '.csv'],'W');

            % format header
            n = obj.Parent.meta.num_traces;
            if any(sz==n)
                header = arrayfun(@(i) sprintf('%s-%i',obj.get_field_name,i), 1:n,...
                    'UniformOutput', false);
                hfs = repmat('%s,',1,n);
                hfs(end) = char(10);
                fprintf(fID, hfs, header{:});
            else
                header = obj.get_field_name;
                hfs = ['%s' char(10)];
                fprintf(fID, hfs, header);
            end

            for i=1:nbatches
                idx = [(i-1)*frames_per_batch+1 i*frames_per_batch];
                if idx(2) > sz(1)
                    batch_dat = obj.raw(idx(1):sz(1),1:obj.dim(end));
                else
                    batch_dat = obj.raw(idx(1):idx(2),1:obj.dim(end));
                end
                fprintf(fID, format_spec, batch_dat');
                reset(obj);
            end
    end
    for i=1:numel(fID)
        fclose(fID(i));
    end
end
