function fe = element2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
fe = ads.baff.ElementFactory(obj,baffOpts);
AttachmentPoints = fe.Points([fe.Points.isAttachmentPoint]);
%generate FE for Children
for i = 1:length(obj.Children)
    fe_comp = ads.baff.element2fe(obj.Children(i),baffOpts);
    AnchorPoints = fe_comp.Points([fe_comp.Points.isAnchorPoint]);
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
        % for beam objects update the yDirection
        for b_i = 1:length(fe_comp.Beams)
            fe_comp.Beams(b_i).yDir = fe.CoordSys(1).A*fe_comp.Beams(b_i).yDir;
        end

    end

    % join
    %find mnimium distance between Parents Attachments points and childs
    %anchor points
    if isempty(AttachmentPoints) || isempty(AnchorPoints)
        error('No availible points to attach the child (%s) to the parent (%s)',obj.Name,obj.Children(i).Name)
    end
    XsAnchor = [AnchorPoints.GlobalPos];
    XsAttach = [AttachmentPoints.GlobalPos];
    dist = inf;
    for Attach_i = 1:length(AttachmentPoints)
        tmp_dist = XsAnchor-repmat(XsAttach(:,Attach_i),1,size(XsAnchor,2));
        [tmp_dist,Anchor_j] = min(vecnorm(tmp_dist));
        if tmp_dist<dist
            dist = tmp_dist;
            index = [Attach_i,Anchor_j];
        end
    end
    if ~isa(obj.Children(i),'baff.Constraint')
        fe.RigidBars(end+1) = ads.fe.RigidBar(AttachmentPoints(index(1)),AnchorPoints(index(2)));
    else
        fe.RigidBars(end+1) = ads.fe.RigidBar(AnchorPoints(index(2)),AttachmentPoints(index(1)));
    end
    
    % the choosen anchor point cannot be a dependent point on any other rigid bar so flip points where required
    PointsToFlip = AnchorPoints(index(2));
    isFlipped = false(1,length(fe_comp.RigidBars));
    while ~isempty(PointsToFlip)      
        for j = 1:length(fe_comp.RigidBars)
            if ~isFlipped(j) && fe_comp.RigidBars(j).Point2 == PointsToFlip(1)
                fe_comp.RigidBars(j).Point2 = fe_comp.RigidBars(j).Point1;
                fe_comp.RigidBars(j).Point1 = PointsToFlip(1);
                PointsToFlip(end+1) = fe_comp.RigidBars(j).Point2;
                isFlipped(j) = true;
            end
        end
        PointsToFlip = PointsToFlip(2:end);
    end
    fe.Components(end+1) = fe_comp;
end
fe.UpdateTag(obj.Name);
end

