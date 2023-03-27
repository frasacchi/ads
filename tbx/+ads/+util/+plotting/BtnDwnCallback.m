function BtnDwnCallback(src, ~)
    if strcmp(get(src, 'SelectionType'), 'normal')
    % -> the left mouse button is clicked once
    % enable the interactive rotation
    userData = get(gca, 'UserData');
    userData.ppos = get(0, 'PointerLocation');
    set(gca, 'UserData', userData)
    set(gcf,'WindowButtonMotionFcn',@ads.util.plotting.BtnMotionCallback)
    ads.util.plotting.BtnMotionCallback(src)   
    elseif strcmp(get(src, 'SelectionType'), 'extend')
    % -> the left mouse button is clicked once
    % enable the interactive rotation
    userData = get(gca, 'UserData');
    userData.ppos = get(0, 'PointerLocation');
    set(gca, 'UserData', userData)
    set(gcf,'WindowButtonMotionFcn',@ads.util.plotting.BtnDragCallback)
    ads.util.plotting.BtnDragCallback(src)
    elseif strcmp(get(src, 'SelectionType'), 'open')
    % -> the left mouse button is double-clicked
    % create a datatip
    cursorMode = datacursormode(src);
    hDatatip = cursorMode.createDatatip(get(gca, 'Children'));
    
    % move the datatip to the position
    ax_ppos = get(gca, 'CurrentPoint');
    ax_ppos = ax_ppos([1, 3, 5]);  
    % uncomment the next line for Matlab R2014a and earlier
    % set(get(hDatatip, 'DataCursor'), 'DataIndex', index, 'TargetPoint', ax_ppos)
    set(hDatatip, 'Position', ax_ppos)
    cursorMode.updateDataCursors    
    end
end