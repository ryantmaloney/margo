classdef RawDataField < handle
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
            try        
                obj.raw.map = memmapfile(obj.path, ...
                                'Format',{obj.precision,fliplr(obj.dim),'raw'});
                            
                % resize of necessary
                sz = size(obj.raw.map.Data);
                if any(sz>1)
                    frame_num = sz(sz>1);
                    obj.dim = [frame_num obj.dim];
                    obj.raw.map = memmapfile(obj.path, ...
                        'Format',{obj.precision,fliplr(obj.dim),'raw'});
                end
            catch 
                % try to automatically repair the file path
                try
                    p = obj.Parent.meta.path;
                    updatepaths(obj.Parent,[p.dir p.name]);
                    obj.raw.map = memmapfile(obj.path, ...
                                'Format',{obj.precision,fliplr(obj.dim),'raw'});
                catch ME
                    switch ME.identifier
                        case 'MATLAB:memmapfile:inaccessibleFile'
                            error(['Failed to initialize raw data map. '...
                                'No such file or directory:\n'...
                                '\t%s'],obj.path);
                    end
                end
            end
        end
        
        function obj = detach(obj)
            obj.raw.map = [];
        end
        
    end
    
    
    
    
end