function fe = element2fe(obj)
[fe,AnchorPoints] = ads.baff.ElementFactory(obj);
%generate FE for Children
for i = 1:length(obj.Children)
    fe_comp = ads.baff.element2fe(obj.Children(i));
    %update coordinate systems to ref parent
    for j = 1:length(fe_comp.CoordSys)
        % update coordinate systems to ref parent
        if isa(fe_comp.CoordSys(j).InputCoordSys,'ads.fe.BaseCoordSys')
            fe_comp.CoordSys(j).InputCoordSys = fe.CoordSys(1);
        end
        % dont correct local referenced frames
        isLocal = false;
        for k = 1:length(fe_comp.CoordSys)
            if fe_comp.CoordSys(j).InputCoordSys == fe_comp.CoordSys(k)
                isLocal = true;
            end
        end
        if isLocal
            continue;
        end
        % update location to account for eta
        eta_vec = obj.GetPos(obj.Children(i).Eta);
        fe_comp.CoordSys(j).Origin = fe_comp.CoordSys(j).Origin + eta_vec;
    end

    % join
    Xs = [AnchorPoints.GlobalPos];
    for k = 1:length(fe_comp.Points)
        if fe_comp.Points(k).JointType ~= ads.fe.JointType.None
            delta = vecnorm(Xs-repmat(fe_comp.Points(k).GlobalPos,1,size(Xs,2)));
            [~,idx] = min(delta);
            switch fe_comp.Points(k).JointType
                case ads.fe.JointType.Rigid
                    fe.RigidBars(end+1) = ads.fe.RigidBar(AnchorPoints(idx),fe_comp.Points(k));
                otherwise
                    error('Joint Type Not Implememnted')
            end
        end
    end
    fe.Components(end+1) = fe_comp;
end
fe.UpdateTag(obj.Name);
end

