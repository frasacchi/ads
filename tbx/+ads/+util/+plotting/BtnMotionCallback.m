function BtnMotionCallback(~, ~)
    % check if the user data exist
    if isempty(get(gca, 'UserData'))
        return
    end
    % camera rotation
    userData = get(gca, 'UserData');
    old_ppos = userData.ppos;
    new_ppos = get(0, 'PointerLocation');


    userData.ppos = new_ppos;
    set(gca, 'UserData', userData)

    dx = (new_ppos(1) - old_ppos(1))*0.25;
    dy = (new_ppos(2) - old_ppos(2))*0.25;
    camorbit(gca, -dx, -dy)
end