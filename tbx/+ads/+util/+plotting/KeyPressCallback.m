function KeyPressCallback(~, eventdata)
% check which key is pressed
if strcmp(eventdata.Key, 'uparrow')
    dx = 0; dy = 0.05;
    camdolly(gca, dx, dy, 0)
elseif strcmp(eventdata.Key, 'downarrow')
    dx = 0; dy = -0.05;
    camdolly(gca, dx, dy, 0)
elseif strcmp(eventdata.Key, 'leftarrow')
    dx = -0.05; dy = 0;
    camdolly(gca, dx, dy, 0)
elseif strcmp(eventdata.Key, 'rightarrow')
    dx = 0.05; dy = 0;
    camdolly(gca, dx, dy, 0)
end

% once again check which key is pressed
if strcmp(eventdata.Key, 'space')
    % restore the original axes and exit the explorer
    userData = get(gcf, 'UserData');
    userData.obj.StopAnimation = true;
end
end