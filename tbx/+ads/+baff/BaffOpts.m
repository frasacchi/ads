classdef BaffOpts
    properties
        SplitBeamsAtChildren = true;
        GenerateAeroPanels = true;
        GenCoordSys = true;
        ChildAttachmentMethod = ads.baff.ChildAttachmentMethod.Closest;
        SeperateSplineForControlSurfaces = false;
        IncludeAeroAddedMass = false;
        AirDensity = 1.225;
        AddedMassStations = 100;
        SecondaryMassStation = 20; % if secondary mass of aero stations, this is hwo many point masses to split them into
        RibStride = 1;             % wing2fe: every n-th beam node gets LE/TE spline nodes
        MassStride = 1;            % wing2fe: every n-th beam node carries lumped secondary mass
        MassOnBeamNode = false;    % wing2fe: lump secondary mass as 6x6 inertia on the beam node
        LeTeEdgeMode = "drop";     % wing2fe: "drop" = skip LE/TE pairs whose beam-normal plane exits via the
                                   % root/(non-tip) tip chord (legacy); "clip" = keep the hit on that chord edge
        AddEndRibs = false;        % wing2fe: add streamwise LE/TE spline nodes at the first/last aero station
    end
    methods
        function obj = BaffOpts(opts)
            arguments
                opts.?ads.baff.BaffOpts
            end
            for prop = string(fieldnames(opts))'
                obj.(prop) = opts.(prop);
            end
        end
    end
end