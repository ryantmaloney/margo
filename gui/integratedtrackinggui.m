function varargout = integratedtrackinggui(varargin)
% INTEGRATEDTRACKINGGUI MATLAB code for integratedtrackinggui.fig
%      INTEGRATEDTRACKINGGUI, by itself, creates a new INTEGRATEDTRACKINGGUI or raises the existing
%      singleton*.
%
%      H = INTEGRATEDTRACKINGGUI returns the handle to a new INTEGRATEDTRACKINGGUI or the handle to
%      the existing singleton*.
%
%      INTEGRATEDTRACKINGGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in INTEGRATEDTRACKINGGUI.M with the given input arguments.
%
%      INTEGRATEDTRACKINGGUI('Property','Value',...) creates a new INTEGRATEDTRACKINGGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before integratedtrackinggui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to integratedtrackinggui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help integratedtrackinggui

% Last Modified by GUIDE v2.5 01-Feb-2017 22:03:38

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @integratedtrackinggui_OpeningFcn, ...
                   'gui_OutputFcn',  @integratedtrackinggui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before integratedtrackinggui is made visible.
function integratedtrackinggui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to integratedtrackinggui (see VARARGIN)

warning('off','MATLAB:JavaEDTAutoDelegation');

% Choose default command line output for integratedtrackinggui
handles.output = hObject;
handles.axes_handle = gca;
handles.gui_dir = which('autotrackergui');
handles.gui_dir = handles.gui_dir(1:strfind(handles.gui_dir,'\gui\'));
handles.display = 1;
set(handles.ROI_thresh_slider,'value',0.15);
set(gca,'Xtick',[],'Ytick',[]);
expmt = [];

% Query available camera and modes
imaqreset
c = imaqhwinfo;

if ~isempty(c.InstalledAdaptors)
    % Select appropriate adaptor for connected camera
    for i = 1:length(c.InstalledAdaptors)
        camInfo = imaqhwinfo(c.InstalledAdaptors{i});
        if ~isempty(camInfo.DeviceIDs)
            adaptor = i;
        end
    end
    if exist('adaptor','var')
        camInfo = imaqhwinfo(c.InstalledAdaptors{adaptor});
    end

    % Set the device to default format and populate pop-up menu
    if ~isempty(camInfo.DeviceInfo);
    set(handles.Cam_popupmenu,'String',camInfo.DeviceInfo.SupportedFormats);
    default_format = camInfo.DeviceInfo.DefaultFormat;

        for i = 1:length(camInfo.DeviceInfo.SupportedFormats)
            if strcmp(default_format,camInfo.DeviceInfo.SupportedFormats{i})
                set(handles.Cam_popupmenu,'Value',i);
                camInfo.ActiveMode = camInfo.DeviceInfo.SupportedFormats(i);
            end
        end

    else
    set(handles.Cam_popupmenu,'String','Camera not detected');
    end
    expmt.camInfo = camInfo;
else
    expmt.camInfo=[];
    set(handles.Cam_popupmenu,'String','No camera adaptors installed');
end
    


% Initialize teensy for motor and light board control

%Close and delete any open serial objects
if ~isempty(instrfindall)
fclose(instrfindall);           % Make sure that the COM port is closed
delete(instrfindall);           % Delete any serial objects in memory
end

% Attempt handshake with light panel teensy
[expmt.teensy_port,ports] = identifyMicrocontrollers;

% Update GUI menus with port names
set(handles.microcontroller_popupmenu,'string',expmt.teensy_port);

% Initialize light panel at default values
IR_intensity = str2num(get(handles.edit_IR_intensity,'string'));
White_intensity = str2num(get(handles.edit_White_intensity,'string'));

% Convert intensity percentage to uint8 PWM value 0-255
expmt.IR_intensity = uint8((IR_intensity/100)*255);
expmt.White_intensity = uint8((White_intensity/100)*255);

% Write values to microcontroller
writeInfraredWhitePanel(expmt.teensy_port,1,expmt.IR_intensity);
writeInfraredWhitePanel(expmt.teensy_port,0,expmt.White_intensity);

% Initialize expmteriment parameters from text boxes in the GUI
expmt.parameters.ref_stack_size  =  str2num(get(handles.edit_ref_stack_size,'String'));
expmt.parameters.ref_freq = str2num(get(handles.edit_ref_freq,'String'));
expmt.parameters.duration = str2num(get(handles.edit_exp_duration,'String'));
expmt.parameters.ROI_thresh = get(handles.ROI_thresh_slider,'Value');
expmt.parameters.tracking_thresh = get(handles.track_thresh_slider,'Value');
expmt.parameters.speed_thresh = 45;
expmt.parameters.distance_thresh = 20;
expmt.parameters.vignette_sigma = 0.47;
expmt.parameters.vignette_weight = 0.35;

if ~isempty(expmt.camInfo)
    expmt.camInfo.Gain = str2num(get(handles.edit_gain,'String'));
    expmt.camInfo.Exposure = str2num(get(handles.edit_exposure,'String'));
    expmt.camInfo.Shutter = str2num(get(handles.edit_cam_shutter,'String'));
    expmt.parameters.target_rate = estimateFrameRate(expmt.camInfo);
else
    expmt.parameters.target_rate = 60;
end

setappdata(handles.figure1,'expmt',expmt);

% Update handles structure
guidata(hObject,handles);

% UIWAIT makes integratedtrackinggui wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = integratedtrackinggui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;






%-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*-* -%
%-*-*-*-*-*-*-*-*-*-*-*-CAMERA FUNCTIONS-*-*-*-*-*-*-*-*-*-*-*-*%
%-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*-*-*%




% --- Executes on selection change in Cam_popupmenu.
function Cam_popupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to Cam_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

expmt = getappdata(handles.figure1,'expmt');

strCell = get(handles.Cam_popupmenu,'string');
expmt.camInfo.ActiveMode = strCell(get(handles.Cam_popupmenu,'Value'));

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function Cam_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Cam_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Cam_confirm_pushbutton.
function Cam_confirm_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Cam_confirm_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if ~isempty(expmt.camInfo)
    if ~isempty(expmt.camInfo.DeviceInfo)
        cla reset
        imaqreset;
        pause(0.02);
        expmt.camInfo = initializeCamera(expmt.camInfo);
        start(expmt.camInfo.vid);
        pause(0.5);
        im = peekdata(expmt.camInfo.vid,1);
        handles.hImage = image(im);
        set(gca,'Xtick',[],'Ytick',[]);
    else
        errordlg('Settings not confirmed, no camera detected');
    end
else
    errordlg('No cameras adaptors installed');
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);





% --- Executes on button press in Cam_preview_pushbutton.
function Cam_preview_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Cam_preview_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if ~isempty(expmt.camInfo) && ~isfield(expmt.camInfo, 'vid')
    errordlg('Please confirm camera settings')
else
    preview(expmt.camInfo.vid,handles.hImage);       
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes on button press in Cam_stopPreview_pushbutton.
function Cam_stopPreview_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Cam_stopPreview_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if ~isempty(expmt.camInfo) && isfield(expmt.camInfo,'vid');
    set(handles.Cam_preview_pushbutton,'Value',0);
    set(handles.Cam_stopPreview_pushbutton,'Value',0);
    stoppreview(expmt.camInfo.vid);
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes on selection change in microcontroller_popupmenu.
function microcontroller_popupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to microcontroller_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns microcontroller_popupmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from microcontroller_popupmenu


% --- Executes during object creation, after setting all properties.
function microcontroller_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to microcontroller_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_IR_intensity_Callback(hObject, eventdata, handles)
% hObject    handle to edit_IR_intensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Initialize light panel at default values

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.IR_intensity = str2num(get(handles.edit_IR_intensity,'string'));

% Convert intensity percentage to uint8 PWM value 0-255
expmt.IR_intensity = uint8((expmt.IR_intensity/100)*255);

writeInfraredWhitePanel(expmt.teensy_port,1,expmt.IR_intensity);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes during object creation, after setting all properties.
function edit_IR_intensity_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_IR_intensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit_White_intensity_Callback(hObject, eventdata, handles)
% hObject    handle to edit_White_intensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

White_intensity = str2num(get(handles.edit_White_intensity,'string'));

% Convert intensity percentage to uint8 PWM value 0-255
expmt.White_intensity = uint8((White_intensity/100)*255);
writeInfraredWhitePanel(expmt.teensy_port,0,expmt.White_intensity);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function edit_White_intensity_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_White_intensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




% --- Executes on button press in save_path_button1.
function save_path_button1_Callback(hObject, eventdata, handles)
% hObject    handle to save_path_button1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');
mat_dir = handles.gui_dir(1:strfind(handles.gui_dir,'MATLAB\')+6);
default_path = [mat_dir 'autotracker_data\'];
if exist(default_path,'dir') ~= 7
    mkdir(default_path);
    msg_title = 'New Data Path';
    message = ['Autotracker has automatically generated a new default directory'...
        ' for data in ' default_path];
    
    % Display info
    waitfor(msgbox(message,msg_title));
end    

[fpath]  =  uigetdir(default_path,'Select a save destination');
expmt.fpath = fpath;
set(handles.save_path,'string',fpath);


% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);






function save_path_Callback(hObject, eventdata, handles)
% hObject    handle to save_path (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of save_path as text
%        str2double(get(hObject,'String')) returns contents of save_path as a double


% --- Executes during object creation, after setting all properties.
function save_path_CreateFcn(hObject, eventdata, handles)
% hObject    handle to save_path (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function labels_uitable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to labels_uitable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

data = cell(5,8);
data(:) = {''};
set(hObject, 'Data', data);
expmt.labels = data;

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes when entered data in editable cell(s) in labels_uitable.
function labels_uitable_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to labels_uitable (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.labels{eventdata.Indices(1), eventdata.Indices(2)} = {''};
expmt.labels{eventdata.Indices(1), eventdata.Indices(2)} = eventdata.NewData;

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




function edit_ref_stack_size_Callback(hObject, eventdata, handles)
% hObject    handle to edit_ref_stack_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.parameters.ref_stack_size = str2num(get(handles.edit_ref_stack_size,'String'));

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function edit_ref_stack_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_ref_stack_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_ref_freq_Callback(hObject, eventdata, handles)
% hObject    handle to edit_ref_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.parameters.ref_freq = str2num(get(handles.edit_ref_freq,'String'));

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes during object creation, after setting all properties.
function edit_ref_freq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_ref_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_exp_duration_Callback(hObject, eventdata, handles)
% hObject    handle to edit_exp_duration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.parameters.duration = str2num(get(handles.edit_exp_duration,'String'));


% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes during object creation, after setting all properties.
function edit_exp_duration_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_exp_duration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if isfield(expmt, 'fpath') == 0 
    errordlg('Please specify Save Location')
elseif ~isfield(expmt, 'camInfo')
    errordlg('Please confirm camera settings')
else
    switch expmt.expID
    	case 2
            projector_escape_response;
        case 3
            projector_optomotor;
        case 4
            projector_slow_phototaxis;
        case 5
            autoTracker_led;
        case 6
            autoTracker_arena;
    end
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes on slider movement.
function ROI_thresh_slider_Callback(hObject, eventdata, handles)
% hObject    handle to ROI_thresh_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.parameters.ROI_thresh = get(handles.ROI_thresh_slider,'Value');
set(handles.disp_ROI_thresh,'string',num2str(round(100*expmt.parameters.ROI_thresh)/100));
guidata(hObject,handles);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes during object creation, after setting all properties.
function ROI_thresh_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ROI_thresh_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in accept_ROI_thresh_pushbutton.
function accept_ROI_thresh_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to accept_ROI_thresh_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

set(handles.accept_ROI_thresh_pushbutton,'value',1);
guidata(hObject,handles);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);



function edit_frame_rate_Callback(hObject, eventdata, handles)
% hObject    handle to edit_frame_rate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_frame_rate as text
%        str2double(get(hObject,'String')) returns contents of edit_frame_rate as a double


% --- Executes during object creation, after setting all properties.
function edit_frame_rate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_frame_rate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in exp_select_popupmenu.
function exp_select_popupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to exp_select_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.expID = get(handles.exp_select_popupmenu,'Value');
names = get(handles.exp_select_popupmenu,'string');
expmt.Name = names{expmt.expID};
expmt.parameters = trimParameters(expmt.parameters);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);
guidata(hObject,handles);

% Hints: contents = cellstr(get(hObject,'String')) returns exp_select_popupmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from exp_select_popupmenu


% --- Executes during object creation, after setting all properties.
function exp_select_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to exp_select_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in begin_reg_button.
function begin_reg_button_Callback(hObject, eventdata, handles)
% hObject    handle to begin_reg_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');


% Turn infrared and white background illumination off during registration
writeInfraredWhitePanel(expmt.teensy_port,1,0);
writeInfraredWhitePanel(expmt.teensy_port,0,0);

msg_title = ['Projector Registration Tips'];
spc = [' '];
intro = ['Please check the following before continuing to ensure successful registration:'];
item1 = ['1.) Both the infrared and white lights for imaging illumination are set to OFF. '...
    'Make sure the projector is the only light source visible to the camera'];
item2 = ['2.) Camera is not imaging through infrared filter. '...
    'Projector display should be visible through the camera.'];
item3 = ['3.) Projector is turned on and set to desired resolution.'];
item4 = ['4.) Camera shutter speed is adjusted to match the refresh rate of the projector.'...
    ' This will appear as moving streaks in the camera if not properly adjusted.'];
item5 = ['5.) Both camera and projector are in fixed positions and will not need to be adjusted'...
    ' after registration.'];
closing = ['Click OK to continue with the registration'];
message = {intro spc item1 spc item2 spc item3 spc item4 spc item5 spc closing};

% Display registration tips
waitfor(msgbox(message,msg_title));

% Register projector
reg_projector(expmt.camInfo,expmt.pixel_step_size,expmt.step_interval,expmt.reg_spot_r,handles.edit_time_remaining);

% Reset infrared and white lights to prior values
writeInfraredWhitePanel(expmt.teensy_port,1,expmt.IR_intensity);
writeInfraredWhitePanel(expmt.teensy_port,0,expmt.White_intensity);

guidata(hObject,handles);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


function edit_time_remaining_Callback(hObject, eventdata, handles)
% hObject    handle to edit_time_remaining (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_time_remaining as text
%        str2double(get(hObject,'String')) returns contents of edit_time_remaining as a double


% --- Executes during object creation, after setting all properties.
function edit_time_remaining_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_time_remaining (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in exp_parameter_pushbutton.
function exp_parameter_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to exp_parameter_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if expmt.expID<2
errordlg('Please select an expmteriment first')
else
    switch expmt.expID
        case 2

        case 3
            
                tmp_param = optomotor_parameter_gui(expmt.parameters);
                if ~isempty(tmp_param)
                    expmt.parameters = tmp_param;
                end

             
             
        case 4                       

                tmp_param = slowphototaxis_parameter_gui(expmt.parameters);
                if ~isempty(tmp_param)
                    expmt.parameters = tmp_param;
                end
                
    end
end



% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);



% --- Executes on button press in refresh_COM_pushbutton.
function refresh_COM_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to refresh_COM_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Refresh items on the COM ports

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

   
% Attempt handshake with light panel teensy
[expmt.teensy_port,ports] = identifyMicrocontrollers;

if ~isempty(ports)
% Update GUI menus with port names
set(handles.microcontroller_popupmenu,'string',expmt.teensy_port);
else
set(handles.microcontroller_popupmenu,'string','COM not detected');
end

guidata(hObject,handles);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes on button press in enter_labels_pushbutton.
function enter_labels_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to enter_labels_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if isfield(expmt,'labels')
    tmp_lbl = label_subgui(expmt.labels);
    if ~isempty(tmp_lbl)
        expmt.labels = tmp_lbl;
    end
else
    tmp_lbl = label_subgui;
    if ~isempty(tmp_lbl)
        expmt.labels = tmp_lbl;
    end
end



% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);



% --- Executes on slider movement.
function track_thresh_slider_Callback(hObject, eventdata, handles)
% hObject    handle to track_thresh_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

expmt.parameters.tracking_thresh = get(handles.track_thresh_slider,'Value');
set(handles.disp_track_thresh,'string',num2str(round(expmt.parameters.tracking_thresh*100)/100));

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


guidata(hObject,handles);




% --- Executes during object creation, after setting all properties.
function track_thresh_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to track_thresh_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in accept_track_thresh_pushbutton.
function accept_track_thresh_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to accept_track_thresh_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

set(handles.accept_track_thresh_pushbutton,'value',1);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes on button press in adv_track_param_pushbutton.
function adv_track_param_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to adv_track_param_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

tmp = advancedTrackingParam_subgui(expmt.parameters);
if ~isempty(tmp)
    expmt.parameters.speed_thresh = tmp.speed_thresh;
    expmt.parameters.distance_thresh = tmp.distance_thresh;
    expmt.parameters.target_rate = tmp.target_rate;
    expmt.parameters.vignette_sigma = tmp.vignette_sigma;
    expmt.parameters.vignette_weight = tmp.vignette_weight;
end
             
% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes on button press in set_dist_scale_pushbutton.
function set_dist_scale_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to set_dist_scale_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

tmp=setDistanceScale_subgui(handles,expmt.parameters);
if ~isempty(tmp)
    expmt.parameters.distance_scale = tmp;
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);



function edit_numObj_Callback(hObject, eventdata, handles)
% hObject    handle to edit_numObj (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_numObj as text
%        str2double(get(hObject,'String')) returns contents of edit_numObj as a double


% --- Executes during object creation, after setting all properties.
function edit_numObj_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_numObj (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function edit_numROIs_Callback(hObject, eventdata, handles)
% hObject    handle to edit_numROIs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_numROIs as text
%        str2double(get(hObject,'String')) returns contents of edit_numROIs as a double


% --- Executes during object creation, after setting all properties.
function edit_numROIs_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_numROIs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in begin_reg_pushbutton.
function begin_reg_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to begin_reg_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

expmt = getappdata(handles.figure1,'expmt');

if isfield(expmt,'reg_params')
    % Turn infrared and white background illumination off during registration
    writeInfraredWhitePanel(expmt.teensy_port,1,0);
    writeInfraredWhitePanel(expmt.teensy_port,0,0);

    msg_title = ['Projector Registration Tips'];
    spc = [' '];
    intro = ['Please check the following before continuing to ensure successful registration:'];
    item1 = ['1.) Both the infrared and white lights for imaging illumination are set to OFF. '...
        'Make sure the projector is the only light source visible to the camera'];
    item2 = ['2.) Camera is not imaging through infrared filter. '...
        'Projector display should be visible through the camera.'];
    item3 = ['3.) Projector is connected to the computer, turned on and set to desired resolution.'];
    item4 = ['4.) Camera shutter speed is adjusted to match the refresh rate of the projector.'...
        ' This will appear as moving streaks in the camera if not properly adjusted.'];
    item5 = ['5.) Both camera and projector are in fixed positions and will not need to be adjusted'...
        ' after registration.'];
    item6 = ['6.) The projector is set as the most external display (ie. the highest number display). Hint: '...
        'this is the most likely problem if the projector is connected but psych Toolbox is drawing to '...
        'the primary display. MATLAB must be restarted before this change will take effect.'];
    closing = ['Click OK to continue with the registration'];
    message = {intro spc item1 spc item2 spc item3 spc item4 spc item5 spc item6 spc closing};

    % Display registration tips
    waitfor(msgbox(message,msg_title));

    % Register projector
    reg_projector(expmt.camInfo,expmt.reg_params,handles);

    % Reset infrared and white lights to prior values
    writeInfraredWhitePanel(handles.teensy_port,1,handles.IR_intensity);
    writeInfraredWhitePanel(handles.teensy_port,0,handles.White_intensity);
else
    errordlg('Set registration parameters before running projector registration.');
end

guidata(hObject, handles);


% --- Executes on button press in reg_param_pushbutton.
function reg_param_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to reg_param_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

if isfield(expmt,'reg_params')
    tmp = registration_parameter_subgui(expmt);
    if ~isempty(tmp)
        expmt.reg_params = tmp;
    end
else
        tmp = registration_parameter_subgui();
    if ~isempty(tmp)
        expmt.reg_params = tmp;
    end
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);


% --- Executes on button press in reg_test_pushbutton.
function reg_test_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to reg_test_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in aux_COM_popupmenu.
function aux_COM_popupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to aux_COM_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns aux_COM_popupmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from aux_COM_popupmenu

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

% Update GUI menus with port names
set(handles.aux_COM_popupmenu,'string',ports);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes during object creation, after setting all properties.
function aux_COM_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to aux_COM_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in refresh_aux_COM_pushbutton.
function refresh_aux_COM_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to refresh_aux_COM_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

% Attempt handshake with light panel teensy
[lightBoardPort,ports] = identifyMicrocontrollers;

% Assign unidentified ports to LED ymaze menu
if ~isempty(ports)
handles.aux_COM_port = ports(1);
else
ports = 'COM not detected';
handles.aux_COM_port = {ports};
end

% Update GUI menus with port names
set(handles.aux_COM_popupmenu,'string',ports);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);

guidata(hObject,handles);




% --- Executes on selection change in param_prof_popupmenu.
function param_prof_popupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to param_prof_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if get(handles.param_prof_popupmenu,'value') ~= 1
    profiles = get(handles.param_prof_popupmenu,'string');
    profile = profiles(get(handles.param_prof_popupmenu,'value'));
    expmt = loadSavedParameters(handles,profile{:});
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);
guidata(hObject,handles);






% --- Executes during object creation, after setting all properties.
function param_prof_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to param_prof_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% Get existing profile list
gui_dir = which('autotrackergui');
gui_dir = gui_dir(1:strfind(gui_dir,'\gui\'));
load_path =[gui_dir 'profiles\'];
tmp_profiles = ls(load_path);
profiles = cell(size(tmp_profiles,1)+1,1);
profiles(1) = {'Select saved settings'};
remove = [];

for i = 1:size(profiles,1)-1;
    k = strfind(tmp_profiles(i,:),'.mat');
    if isempty(k)
        remove = [remove i+1];
    else
        profiles(i+1) = {tmp_profiles(i,1:k-1)};
    end
end

profiles(remove)=[];
if size(profiles,1) > 1
    set(hObject,'string',profiles);
else
    set(hObject,'string',{'No profiles detected'});
end


% --- Executes on button press in save_params_pushbutton.
function save_params_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to save_params_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment data struct
expmt = getappdata(handles.figure1,'expmt');

% set profile save path
save_path = [handles.gui_dir 'profiles\'];

[FileName,PathName] = uiputfile('*.mat','Enter name for new profile',save_path);

if any(FileName)
    replace = exist(strcat(PathName,FileName),'file')==2;
    save(strcat(PathName,FileName),'expmt');

    if replace
        profile_name = FileName(1:strfind(FileName,'.mat')-1);
        profiles = get(handles.param_prof_popupmenu,'string');
        
        for i = 1:length(profiles)
            if strcmp(profile_name,profiles{i});
                ri = i;
            end
        end
        
        profiles(ri) = {profile_name};
        set(handles.param_prof_popupmenu,'string',profiles);
        set(handles.param_prof_popupmenu,'value',ri);
        
    else
        profile_name = FileName(1:strfind(FileName,'.mat')-1);
        profiles = get(handles.param_prof_popupmenu,'string');
        profiles(1) = {'Select saved settings'};
        profiles(size(profiles,1)+1) = {profile_name};
        set(handles.param_prof_popupmenu,'string',profiles);
        set(handles.param_prof_popupmenu,'value',size(profiles,1));
    end
end


% --- Executes during object deletion, before destroying properties.
function ROI_thresh_slider_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to ROI_thresh_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in reference_pushbutton.
function reference_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to reference_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment variables
expmt = getappdata(handles.figure1,'expmt');

if isfield(expmt,'ROI')
    expmt = initializeRef(handles,expmt);
else
    errordlg('ROI detection must be run before initializing references')
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);
guidata(hObject,handles);




% --- Executes on button press in sample_noise_pushbutton.
function sample_noise_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to sample_noise_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment variables
expmt = getappdata(handles.figure1,'expmt');

if isfield(expmt,'ref')
    expmt = sampleNoise(handles,expmt);
else
    errordlg('Reference image required to sample tracking noise')
end

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);
guidata(hObject,handles);


% --- Executes on button press in auto_detect_ROIs_pushbutton.
function auto_detect_ROIs_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to auto_detect_ROIs_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment variables
expmt = getappdata(handles.figure1,'expmt');

% autodetect ROIs
[corners, centers, orientation, bounds, im] = autoROIs(handles);

expmt.ROI = [];
expmt.ROI.corners = corners;
expmt.ROI.centers = centers;
expmt.ROI.orientation = orientation;
expmt.ROI.bounds = bounds;
expmt.ROI.im = im;

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);
guidata(hObject,handles);




% ***************** Menu Items ******************** %




% --------------------------------------------------------------------
function hardware_props_menu_Callback(hObject, eventdata, handles)
% hObject    handle to hardware_props_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function display_menu_Callback(hObject, eventdata, handles)
% hObject    handle to display_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function cam_settings_menu_Callback(hObject, eventdata, handles)
% hObject    handle to cam_settings_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% import expmteriment variables
expmt = getappdata(handles.figure1,'expmt');

% run camera settings gui
expmt = cam_settings_subgui(handles,expmt);

% Store expmteriment data struct
setappdata(handles.figure1,'expmt',expmt);
guidata(hObject,handles);




% --------------------------------------------------------------------
function proj_settings_menu_Callback(hObject, eventdata, handles)
% hObject    handle to proj_settings_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Untitled_3_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function display_difference_menu_Callback(hObject, eventdata, handles)
% hObject    handle to display_difference_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

chk = get(hObject,'checked');

if strcmp(chk,'off')
    handles.display = 2;
    set(handles.display_difference_menu,'checked','on');
    set(handles.display_raw_menu,'checked','off');
    set(handles.display_threshold_menu,'checked','off');
    set(handles.display_none_menu,'checked','off');
end

guidata(hObject,handles);


% --------------------------------------------------------------------
function display_raw_menu_Callback(hObject, eventdata, handles)
% hObject    handle to display_raw_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

chk = get(hObject,'checked');

if strcmp(chk,'off')
    handles.display = 1;
    set(handles.display_difference_menu,'checked','off');
    set(handles.display_raw_menu,'checked','on');
    set(handles.display_threshold_menu,'checked','off');
    set(handles.display_none_menu,'checked','off');
end

guidata(hObject,handles);


% --------------------------------------------------------------------
function display_threshold_menu_Callback(hObject, eventdata, handles)
% hObject    handle to display_threshold_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

chk = get(hObject,'checked');

if strcmp(chk,'off')
    handles.display = 3;
    set(handles.display_difference_menu,'checked','off');
    set(handles.display_raw_menu,'checked','off');
    set(handles.display_threshold_menu,'checked','on');
    set(handles.display_none_menu,'checked','off');
end

guidata(hObject,handles);


% --------------------------------------------------------------------
function display_none_menu_Callback(hObject, eventdata, handles)
% hObject    handle to display_none_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

chk = get(hObject,'checked');

if strcmp(chk,'off')
    handles.display = 4;
    set(handles.display_difference_menu,'checked','off');
    set(handles.display_raw_menu,'checked','off');
    set(handles.display_threshold_menu,'checked','off');
    set(handles.display_none_menu,'checked','on');
end

guidata(hObject,handles);


% --------------------------------------------------------------------
function reg_proj_menu_Callback(hObject, eventdata, handles)
% hObject    handle to reg_proj_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function reg_params_menu_Callback(hObject, eventdata, handles)
% hObject    handle to reg_params_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function reg_error_menu_Callback(hObject, eventdata, handles)
% hObject    handle to reg_error_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in popupmenu6.
function popupmenu6_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu6 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu6


% --- Executes during object creation, after setting all properties.
function popupmenu6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
