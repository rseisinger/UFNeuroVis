function mer_plot_callback(aH,event,ApmDataTable)
%{
MER_PLOT_CALLABCK
    Updates the disp_axes with the APM channel data of the closest point
    to the user's click.
ARGS
    aH: handle of axes to plot 3D trajectory on
RETURNS
    None
%}

    % this will return the row-index and pass-index of the closest match
    [iPoint,iPass] = get_point_coord(aH);

    % if a match is found,
    if iPoint ~= 0 && iPass ~= 0
        match = ApmDataTable{iPass}.match(iPoint);
        display_match(aH,match,iPass);
        
        audio_ret = audio_tracker_create(aH,ApmDataTable,iPass,iPoint);
        
        f = ancestor(aH,'figure');
        handles = guidata(f);
        set(handles.wave_clus_button,'enable','on')
        set(handles.export_button,'enable','on')
        if audio_ret
            set(handles.play_audio_button,'enable','on')
            set(handles.pause_audio_button,'enable','on')
        end
        guidata(f,handles)
    end    

end

