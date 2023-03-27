function cbToggleVisible(~, evt)
    %cbToggleVisible Toggles the visibility of a all graphic objects with 
    % the same tag as the one clicked on in the legend.
    if isprop(evt.Peer, 'Tag')
        objs = findobj('Tag',evt.Peer.Tag);
        for i = 1:length(objs)
            if ~isprop(objs(i), 'Visible')
                continue
            else
                switch objs(i).Visible
                    case 'on'
                        objs(i).Visible = 'off';
                    case 'off'
                        objs(i).Visible = 'on';
                end
            end
        end
    elseif isprop(evt.Peer, 'Visible')
        switch evt.Peer.Visible
            case 'on'
                evt.Peer.Visible = 'off';
            case 'off'
                evt.Peer.Visible = 'on';
        end
    end    
end