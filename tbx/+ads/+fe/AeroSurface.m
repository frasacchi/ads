classdef AeroSurface < ads.fe.Element
    %MASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        CoordSys (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
        AeroCoordSys (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
        Points (3,2) double
        ChordwisePos (2,1) double = [nan nan];
        ChordVecs (3,2) double = [-1,-1;0,0;0,0];
        Chords (2,1) double = [nan nan];
        Twists (2,1) double = [0 0];
        EtaSpan (1,:) double = linspace(0,1,11);
        EtaChord (1,:) double = linspace(0,1,5);
        StructuralPoints (:,1) ads.fe.Point;
        DisplacementPoints (:,1) ads.fe.Point;
        ID double = nan;
        PID (1,1) double = nan;
        SID (4,1) double = [nan,nan,nan,nan];
        SplineType = 4;
        SplineMeth = 'IPS';
        HingeEta (1,1) double = nan;        % if not nan specifies the eta value of the hinge for a TE control surface
        CrossEta = 0.5;
        LiftCurveSlope = 2*pi;
        MomentCurveSlope = 2*pi;
        IsWall = false; % if true the surface is a wall and will have zero downwash applied to it regardless of angle
        ControlSurface = ads.fe.ControlSurface.empty;
    end

    properties(Dependent)
        nChord
        nSpan
        nPanels
        CentroidsGlobal
        Area
    end
    methods
        function obj = set.HingeEta(obj,val)
            obj.HingeEta = val;
            obj.nChord = obj.nChord; % enforce recalc of etachord
        end
        function n = get.nPanels(obj)
            n = obj.nSpan * obj.nChord;
        end
        function n = get.nChord(obj)
            n = length(obj.EtaChord)-1;
        end
        function x = get.CentroidsGlobal(obj)
            x = obj.CoordSys.getPointGlobal(obj.get_centroids());
        end
        function a = get.Area(obj)
            Xs = obj.get_panel_coords;
            a = ones(1,obj.nPanels);
            for i = 1:length(a)
                v1 = Xs(1,:,i) - Xs(3,:,i);
                v2 = Xs(2,:,i) - Xs(4,:,i);
                a(i) = 0.5*abs(norm(cross(v2,v1)));
            end
        end
        function n = get.nSpan(obj)
            n = length(obj.EtaSpan)-1;
        end
        function obj = set.nChord(obj,val)
            if isnan(obj.HingeEta)
                obj.EtaChord = linspace(0,1,val+1);
            else
                N_main = max(3,round(val*obj.HingeEta));
                N_tab = max(2,round(val*(1-obj.HingeEta)));
                etaMain = linspace(0,obj.HingeEta,N_main+1);
                obj.EtaChord = [etaMain(1:end-1),linspace(obj.HingeEta,1,N_tab+1)];
            end
        end
        function obj = set.nSpan(obj,val)
            obj.EtaSpan = linspace(0,1,val+1);
        end
    end
    
    methods
        function idx = HingeIdx(obj)
            idx = false(obj.nChord,obj.nSpan);
            if ~isnan(obj.HingeEta)
                nMain = nnz(obj.EtaChord<obj.HingeEta);
                idx(nMain+1:end,:) = true;
            end
            idx = idx(:);
        end
        function obj = AeroSurface(Points,ChordwisePos,Chords,opts)
            arguments
                Points (3,2) double
                ChordwisePos (2,1) double
                Chords (2,1) double
                opts.CoordSys (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.Twists (2,1) double = [0,0];
                opts.nSpan (1,1) double = 10;
                opts.nChord (1,1) double = 4;
                opts.StructuralPoints (:,1) ads.fe.Point = ads.fe.Point.empty;
                opts.DisplacementPoints (:,1) ads.fe.Point = ads.fe.Point.empty;
            end
            %MASS Construct an instance of this class
            %   Detailed explanation goes here
            obj.CoordSys = opts.CoordSys;
            obj.Points = Points;
            obj.ChordwisePos = ChordwisePos;
            obj.Chords = Chords;
            obj.Twists = opts.Twists;
            obj.nSpan = opts.nSpan;
            obj.nChord = opts.nChord;
            obj.StructuralPoints = opts.StructuralPoints;
            obj.DisplacementPoints = opts.DisplacementPoints;
        end
        function SetPanelNumbers(obj,N,AspectRatio,Dependent)
            arguments
                obj
                N (1,1) double
                AspectRatio (1,1) double
                Dependent string {mustBeMember(Dependent,{'Span','Chord'})}
            end
            for i = 1:length(obj)
            switch Dependent
                case 'Span'
                    obj(i).nChord = N;
                    span = vecnorm(obj(i).Points(:,2)-obj(i).Points(:,1));
                    panelChord = obj(i).Chords(2)/N;
                    panelspan = panelChord*AspectRatio;
                    obj(i).nSpan = ceil(span/panelspan);
                case 'Chord'
                    obj(i).nSpan = N;
                    span = vecnorm(obj(i).Points(:,2)-obj(i).Points(:,1));
                    panelSpan = span/N;
                    panelChord = panelSpan/AspectRatio;
                    obj(i).nChord = ceil(obj(i).Chords(2)/panelChord);
            end
            end
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                % resurve EIDs for each panel and upto 3 Spline cards
                ids.EID = ids.EID + (obj(i).nSpan*obj(i).nChord) + 3;
                % for PAERO cards
                obj(i).PID = ids.PID;
                ids.PID = ids.PID + 1;
                % for AELIST and SET1 for spline + 1 extra incase two meshes used
                obj(i).SID = ids.SID:(ids.SID+3);
                ids.SID = ids.SID + 5;
            end
        end
        function plt_obj = drawElement(obj)
            if isempty(obj)
                plt_obj = [];
                return;
            end
            for i = 1:length(obj)
                Xs = obj(i).get_panel_coords();
                for j = 1:size(Xs,3)
                    Xs(:,:,j) = obj(i).CoordSys.getPointGlobal(Xs(:,:,j)')';
                end
                X = reshape(Xs(:,1,:),4,[]);
                Y = reshape(Xs(:,2,:),4,[]);
                Z = reshape(Xs(:,3,:),4,[]);
                c = repmat(201/255,size(X,2),3);
                if ~isnan(obj(i).HingeEta)
                    hIdx = obj(i).HingeIdx();
                    c(hIdx,:) = repmat([1,0,0],nnz(hIdx),1);
                end
                c = reshape(c,size(X,2),1,3);
                plt_obj(i) = patch('XData', X,'YData', Y,'ZData', Z,...
                    'Tag', 'Aero Panels', 'CData', c,'FaceColor','flat');
            end
        end
        function CS = getHingeCoordSys(obj)
            if isnan(obj.HingeEta)
                CS = ad.fe.CoordSys.empty;
                return
            end
            Panel_Xs = obj.get_panel_coords();
            hIdx = find(obj.HingeIdx(),1);
            HingePanel_Xs = Panel_Xs(:,:,hIdx)';
            Hy = HingePanel_Xs(:,4)-HingePanel_Xs(:,1);
            Hy = Hy./norm(Hy);
            Hz = cross((HingePanel_Xs(:,3)-HingePanel_Xs(:,1)),(HingePanel_Xs(:,4)-HingePanel_Xs(:,2)));
            Hz = Hz./norm(Hz);
            Hx = cross(Hy,Hz);
            CS = ads.fe.CoordSys("Origin",HingePanel_Xs(:,1),"A",[Hx,Hy,Hz],"InputCoord",obj.CoordSys);
        end
        function Xs = get_panel_coords(obj)
            Xs = zeros(4,3,sum([obj.nPanels]));
            idx = 1;
            for i = 1:length(obj)
                xDirGlobal = obj(i).AeroCoordSys.getAglobal()*[1;0;0];
                xDirLocal = obj(i).CoordSys.getAglobal()'*xDirGlobal;
                P1 = obj(i).Points(:,1) + obj(i).ChordVecs(:,1)*obj(i).Chords(1).*(obj(i).CrossEta-obj(i).ChordwisePos(1));
                P2 = obj(i).Points(:,2) + obj(i).ChordVecs(:,2)*obj(i).Chords(2).*(obj(i).CrossEta-obj(i).ChordwisePos(2));
                X1 = P1 - obj(i).Chords(1)*xDirLocal*obj(i).CrossEta;
                X4 = P2 - obj(i).Chords(2)*xDirLocal*obj(i).CrossEta;
                X2 = X1 + obj(i).Chords(1)*xDirLocal;
                X3 = X4 + obj(i).Chords(2)*xDirLocal;
                V12 = X2-X1;
                V43 = X3-X4;
                V14 = X4-X1;
                etaChord = obj(i).EtaChord;
                etaSpan = obj(i).EtaSpan;
                for j = 1:obj(i).nSpan
                    Vc = interp1([0 1],[V12,V43]',etaSpan(j:(j+1)))';
                    Xle = [X1,X1] + [V14,V14].*repmat(etaSpan(j:(j+1)),3,1);
                    for k = 1:obj(i).nChord
                        Xs(1,:,idx) = Xle(:,1) + Vc(:,1)*etaChord(k);
                        Xs(2,:,idx) = Xle(:,1) + Vc(:,1)*etaChord(k+1);
                        Xs(3,:,idx) = Xle(:,2) + Vc(:,2)*etaChord(k+1);
                        Xs(4,:,idx) = Xle(:,2) + Vc(:,2)*etaChord(k);
                        idx = idx + 1;
                    end
                end
            end
        end
        function Xs = get_centroids(obj)
            %get total number of panels
            Panel_Xs = obj.get_panel_coords();
            Xs = zeros(3,obj.nChord*obj.nSpan);
            for j = 1:obj.nChord*obj.nSpan
                Xs(:,j) = mean(Panel_Xs(:,:,j),1)';
            end
        end
        function Ns = get_normal(obj)
            xDirGlobal = obj.AeroCoordSys.getAglobal()*[1;0;0];
            xDirLocal = obj.CoordSys.getAglobal()'*xDirGlobal;
            N = cross(xDirLocal,[0 1 0]');
            Ns = repmat(N,1,obj.nChord*obj.nSpan);
        end
        function IDs = get_panelIDs(obj)
            IDs = (0:1:(obj.nChord*obj.nSpan - 1)) + obj.ID;
        end
        function angles = get_twists(obj)
            angles = {};
            for i = 1:length(obj)
                xDirGlobal = obj(i).AeroCoordSys.getAglobal()*[1;0;0];
                xDirLocal = obj(i).CoordSys.getAglobal()'*xDirGlobal;
                % get local AoA at each end
                n = cross(-obj(i).ChordVecs(:,1),[0;0;1]);
                n = n./norm(n);
                angle_1 = atan2d(cross(xDirLocal,obj(i).ChordVecs(:,1))'*n,xDirLocal'*obj(i).ChordVecs(:,1));
                angle_2 = atan2d(cross(xDirLocal,obj(i).ChordVecs(:,2))'*n,xDirLocal'*obj(i).ChordVecs(:,2));
                twistEta = linspace(angle_1,angle_2,obj(i).nSpan*2+1);
                twistEta = twistEta(2:2:end);
                angles{i} = reshape(repmat(twistEta,obj(i).nChord,1),[],1)'; 

                P2 = obj(i).Points(:,2) + obj(i).ChordVecs(:,2)*obj(i).Chords(2).*(obj(i).CrossEta-obj(i).ChordwisePos(2));
                X4 = P2 - obj(i).Chords(2)*xDirLocal*obj(i).CrossEta; 
                if X4(1) < 0 
                    angles{i} = -angles{i};
                end
                if obj(i).IsWall
                    angles{i} = angles{i}*0;
                end
            end
            [~,idx] = sort([obj.ID]);
            angles = [angles{idx}];
        end
        function [cl_alpha,c_m] = get_correction_factor(obj)
            cl_alpha = {};
            c_m = {};
            for i = 1:length(obj)
                cl_alpha{i} = ones(1,obj(i).nChord * obj(i).nSpan) * obj(i).LiftCurveSlope;
                c_m{i} = ones(1,obj(i).nChord * obj(i).nSpan) * obj(i).MomentCurveSlope;
            end
            [~,idx] = sort([obj.ID]);
            cl_alpha = [cl_alpha{idx}]./(2*pi);
            c_m = [c_m{idx}]./(2*pi);

        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"CAERO1 : Defines Aerodyanmic Panels");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                angles = obj.get_twists();
                [cl_alpha,c_m] = obj.get_correction_factor();
                for i = 1:length(obj)
                    xDirGlobal = obj(i).AeroCoordSys.getAglobal()*[1;0;0];
                    xDirLocal = obj(i).CoordSys.getAglobal()'*xDirGlobal;
                    P1 = obj(i).Points(:,1) + obj(i).ChordVecs(:,1).*obj(i).Chords(1).*(obj(i).CrossEta-obj(i).ChordwisePos(1));
                    P2 = obj(i).Points(:,2) + obj(i).ChordVecs(:,2)*obj(i).Chords(2).*(obj(i).CrossEta-obj(i).ChordwisePos(2));
                    X1 = P1 - obj(i).Chords(1)*xDirLocal*obj(i).CrossEta;
                    X4 = P2 - obj(i).Chords(2)*xDirLocal*obj(i).CrossEta;
                    % if no hinge use nChord and nSpan to define the density of panels
                    if isnan(obj(i).HingeEta)
                        mni.printing.cards.CAERO1(obj(i).ID,obj(1).PID,X1,X4,...
                            obj(i).Chords(1),obj(i).Chords(2),1,...
                            NSPAN=obj(i).nSpan,NCHORD=obj(i).nChord,CP=obj(i).CoordSys.ID).writeToFile(fid);
                    % if a hinge exists use the etaChord list in an AEFACT card to define chordwise density
                    else
                        mni.printing.cards.CAERO1(obj(i).ID,obj(1).PID,X1,X4,...
                            obj(i).Chords(1),obj(i).Chords(2),1,...
                            NSPAN=obj(i).nSpan,LCHORD=obj(i).SID(4),CP=obj(i).CoordSys.ID).writeToFile(fid);
                        mni.printing.cards.AEFACT(obj(i).SID(4),obj(i).EtaChord).writeToFile(fid);
                    end
                end
                %print DMI entry
                [~,idx] = sort([obj.ID]);
                DMI_W2GJ = mni.printing.cards.DMI('W2GJ',deg2rad(angles(:)),2,1,0);
                DMI_W2GJ.writeToFile(fid);
                DMI_WKK = mni.printing.cards.DMI('WKK',reshape([cl_alpha;c_m],[],1),3,1,0);
                DMI_WKK.writeToFile(fid);
                %print aero properties
                mni.printing.bdf.writeComment(fid,"PAERO1 : Defines Aerodyanmic Properties for panels");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                % for i = 1:length(obj)
                mni.printing.cards.PAERO1(obj(1).PID).writeToFile(fid);
                % end
                %print aero spline
                mni.printing.bdf.writeComment(fid,"Aerodynamic Splines: Defined by a SPLINE, AELIST and SET1 card");
                for i = 1:length(obj)
                    if numel(obj(i).StructuralPoints)>0
                        splitMesh = ~isempty(obj(i).DisplacementPoints);
                        if splitMesh
                            usage = 'FORCE';
                        else
                            usage = 'BOTH';
                        end
                        switch obj(i).SplineType
                            case 4
                                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                                id = obj(i).ID + (obj(i).nSpan*obj(i).nChord);
                                % if structural points have been specified on the control surface spline it seperately
                                if isempty(obj(i).ControlSurface) || isempty(obj(i).ControlSurface(1).StructuralPoints)
                                    % only add spline for main wing
                                    mni.printing.cards.SPLINE4(id,obj(i).ID,obj(i).SID(1),obj(i).SID(2),USAGE=usage,METH=obj(i).SplineMeth).writeToFile(fid);
                                    mni.printing.cards.AELIST(obj(i).SID(1),obj(i).ID:(id-1)).writeToFile(fid);
                                    mni.printing.cards.SET1(obj(i).SID(2),[obj(i).StructuralPoints.ID]).writeToFile(fid);
                                else
                                    % get ids of main wing and control surface aero panels
                                    p_ids = reshape(obj(i).ID:(id-1),obj(i).nChord,obj(i).nSpan);
                                    hinge_id = find(obj(i).EtaChord==obj(i).HingeEta,1);
                                    main_id = reshape(p_ids(1:(hinge_id-1)),1,[]);
                                    control_id = reshape(p_ids(hinge_id:end),1,[]);
                                    % add spline for main wing
                                    mni.printing.cards.SPLINE4(id,obj(i).ID,obj(i).SID(1),obj(i).SID(2),USAGE=usage,METH=obj(i).SplineMeth).writeToFile(fid);
                                    mni.printing.cards.AELIST(obj(i).SID(1),main_id).writeToFile(fid);
                                    mni.printing.cards.SET1(obj(i).SID(2),[obj(i).StructuralPoints.ID]).writeToFile(fid);
                                    % add spline for control surface
                                    mni.printing.cards.SPLINE4(id+2,obj(i).ID,obj(i).SID(4),obj(i).ControlSurface(1).SID_struct,USAGE=usage,METH=obj(i).SplineMeth).writeToFile(fid);
                                    mni.printing.cards.AELIST(obj(i).SID(4),control_id).writeToFile(fid);
                                end
                                if splitMesh
                                    mni.printing.cards.SPLINE4(id+1,obj(i).ID,obj(i).SID(1),obj(i).SID(5),USAGE='DISP',METH=obj(i).SplineMeth,FTYPE='WF2',RCORE=0.5).writeToFile(fid);
                                    mni.printing.cards.SET1(obj(i).SID(3),[obj(i).DisplacementPoints.ID]).writeToFile(fid);
                                end
                            case 6
                                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                                id = obj(i).ID + (obj(i).nSpan*obj(i).nChord);
                                mni.printing.cards.SPLINE4(id,obj(i).ID,obj(i).SID(1),obj(i).SID(2),USAGE=usage).writeToFile(fid);
                                mni.printing.cards.AELIST(obj(i).SID(1),obj(i).ID:(id-1)).writeToFile(fid);
                                mni.printing.cards.SET1(obj(i).SID(2),[obj(i).StructuralPoints.ID]).writeToFile(fid);
                                if splitMesh
                                    mni.printing.cards.SPLINE6(id+1,obj(i).ID,obj(i).SID(1),obj(i).SID(3),USAGE='DISP').writeToFile(fid);
                                    mni.printing.cards.SET1(obj(i).SID(3),[obj(i).DisplacementPoints.ID]).writeToFile(fid);
                                end
                            case 7
                                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                                id = obj(i).ID + (obj(i).nSpan*obj(i).nChord);
                                mni.printing.cards.SPLINE7(id,obj(i).ID,obj(i).SID(1),obj(i).SID(2),obj(i).CoordSys.ID,USAGE=usage).writeToFile(fid);
                                mni.printing.cards.AELIST(obj(i).SID(1),obj(i).ID:(id-1)).writeToFile(fid);
                                mni.printing.cards.SET1(obj(i).SID(2),[obj(i).StructuralPoints.ID]).writeToFile(fid);
                                if splitMesh
                                    mni.printing.cards.SPLINE7(id+1,obj(i).ID,obj(i).SID(1),obj(i).SID(3),obj(i).CoordSys.ID,USAGE='DISP',DTOR=0.1).writeToFile(fid);
                                    mni.printing.cards.SET1(obj(i).SID(3),[obj(i).DisplacementPoints.ID]).writeToFile(fid);
                                end
                            otherwise
                                error('Unkown Spline Type %.0f',obj(i).SplineType)

                        end
                    end
                end
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
            end
        end
    end
end

