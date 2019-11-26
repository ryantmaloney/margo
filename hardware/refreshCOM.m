function [expmt, handles] = refreshCOM(expmt, handles)

% Initialize teensy for motor and light board control

%Close and delete any open serial objects
if ~isempty(instrfindall)
    fclose(instrfindall);       % Make sure that the COM port is closed
    delete(instrfindall);       % Delete any serial objects in memory
end

% Attempt handshake with light panel teensy
[light_COM, ports, all_COM_devices] = identifyMicrocontrollers;
expmt.hardware.COM.light = light_COM;
expmt.hardware.COM.ports = ports;
expmt.hardware.COM.devices = all_COM_devices;
expmt.hardware.COM.settings = cell(numel(all_COM_devices), 1);
expmt.hardware.COM.status = cellfun(@(dev) dev.status, ...
    all_COM_devices, 'UniformOutput', false);



% filter out unavailble ports
if ~iscell(expmt.hardware.COM.ports)
    expmt.hardware.COM.ports = {expmt.hardware.COM.ports};
end
unavailable = cellfun(@(p) ...
    any(strfind(p,'(unavailable)')), expmt.hardware.COM.ports);
port_list = expmt.hardware.COM.ports(~unavailable);


% Update GUI menus with port names
if ~isempty(port_list)
    handles.microcontroller_popupmenu.String = port_list;
else
    handles.microcontroller_popupmenu.String = 'No COM detected';
end

% automatically select light COM if detected
if ~isempty(expmt.hardware.COM.light)
    handles.microcontroller_popupmenu.Value = ...
        find(strcmp(expmt.hardware.COM.ports,expmt.hardware.COM.light.Port));
end
        

% Initialize light panel at default values
IR_intensity = str2double(get(handles.edit_IR_intensity,'string'));
White_intensity = str2double(get(handles.edit_White_intensity,'string'));


% Convert intensity percentage to uint8 PWM value 0-255
expmt.hardware.light.infrared = uint8((IR_intensity/100)*255);
expmt.hardware.light.white = uint8((White_intensity/100)*255);

% Write values to microcontroller
writeInfraredWhitePanel(expmt.hardware.COM.light,1,...
    expmt.hardware.light.infrared);
writeInfraredWhitePanel(expmt.hardware.COM.light,0,...
    expmt.hardware.light.white);

% generate menu items for AUX COMs and config their callbacks
hParent = findobj('Tag','aux_com_menu');

% remove controls for existing list
del=[];
for i = 1:length(hParent.Children)
    if ~strcmp(hParent.Children(i).Label,'refresh list')
        del = [del i];
    end
end
delete(hParent.Children(del));

        

% generate controls for new list
expmt.hardware.COM.aux = [];
for i = 1:length(expmt.hardware.COM.ports)
    menu_items(i) = uimenu(hParent,'Label',expmt.hardware.COM.ports{i},...
        'Callback',@aux_com_list_Callback);
    if i ==1
        menu_items(i).Separator = 'on';
    end
    if unavailable(i)
        menu_items(i).Enable = 'off';
    end
end

if ~isempty(expmt.hardware.COM.light)
    light_idx = ...
        find(strcmp(expmt.hardware.COM.light.port,expmt.hardware.COM.ports));
    menu_items(light_idx).Enable = 'off';
end