classdef LBeam < ads.fe.Element
    %LBEAM CBEAM element with PBEAML cross-section.
    %
    %   Mirrors ads.fe.Beam but exports CBEAM + PBEAML instead of
    %   CBEAM + PBEAM. The PBEAML card uses Nastran's MSCBML0 library
    %   of cross-section shapes (ROD, TUBE, BAR, BOX, L, I, CHAN, T, Z,
    %   HAT, HAT1, ...) addressed by a TYPE string + DIM array, rather
    %   than analytic A/I/J properties.
    %
    %   Each ads.fe.LBeam is ONE CBEAM connecting two ads.fe.Points (End A
    %   and End B) with ONE attached PBEAML. The PBEAML carries two
    %   cross-section stations (X = 0 and X = 1) so the section can taper
    %   linearly along the segment. A multi-station baff.station.LBeam
    %   maps to (N-1) ads.fe.LBeam objects via FromBaffLBeam — one per
    %   inter-station segment — because intermediate PBEAML sections are
    %   virtual and do not share GRIDs with the rest of the mesh.

    properties
        Stations (:,1) ads.fe.LBeamStation
        ID  double = nan;
        PID double = nan;
        G0  ads.fe.Point = ads.fe.Point.empty
        yDir (3,1) double = [0;1;0];
        Type  (1,1) string = ""           % PBEAML cross-section TYPE
        Group (1,1) string = "MSCBML0"    % PBEAML GROUP (cross-section library)
        ExportLongFormat logical = false;
    end

    methods
        function obj = LBeam(stations, opts)
            arguments
                stations (2,1) ads.fe.LBeamStation
                opts.yDir  (3,1) double = [0;1;0]
                opts.Type  (1,1) string = ""
                opts.Group (1,1) string = "MSCBML0"
            end
            obj.Stations = stations;
            obj.yDir  = opts.yDir;
            obj.Type  = opts.Type;
            obj.Group = opts.Group;
        end

        function m = GetMass(obj)
            % Mass via cross-section area from TYPE + DIM, integrated as
            % a frustum (V = h·(A1 + A2 + sqrt(A1·A2))/3) over each
            % inter-station segment. Mirrors ads.fe.Beam.GetMass.
            m = zeros(size(obj));
            for i = 1:length(obj)
                tmp_m  = 0;
                A_prev = ads.fe.LBeam.AreaFromTypeDIM(obj(i).Type, obj(i).Stations(1).DIM);
                for j = 2:length(obj(i).Stations)
                    h  = norm(obj(i).Stations(j).Point.GlobalPos - obj(i).Stations(j-1).Point.GlobalPos);
                    A  = ads.fe.LBeam.AreaFromTypeDIM(obj(i).Type, obj(i).Stations(j).DIM);
                    V  = h * (A_prev + A + sqrt(A_prev * A)) / 3;
                    tmp_m  = tmp_m + V * obj(i).Stations(j-1).Mat.rho;
                    A_prev = A;
                end
                m(i) = tmp_m;
            end
        end

        function ids = UpdateID(obj, ids)
            for i = 1:length(obj)
                obj(i).ID  = ids.EID;  ids.EID = ids.EID + 1;
                obj(i).PID = ids.PID;  ids.PID = ids.PID + 1;
            end
        end

        function plt_obj = drawElement(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            for i = 1:length(obj)
                st = [obj(i).Stations];
                ps = [st(:).Point];
                Xs = [ps.GlobalPos];
                plt_obj(i) = plot3(Xs(1,:), Xs(2,:), Xs(3,:), 'ko-');
                plt_obj(i).MarkerFaceColor = [0.3, 0.3, 0.3];
                plt_obj(i).Tag = "LBeam (" + obj(i).Type + ")";
            end
        end

        function Export(obj, fid)
            if ~isempty(obj)
                obj.ExportToCBEAML(fid);
            end
        end

        function ExportToCBEAML(obj, fid)
            if isempty(obj); return; end

            % --- CBEAM cards -----------------------------------------
            mni.printing.bdf.writeComment(fid, ...
                "CBEAM (PBEAML) : Beam element with library cross-section.");
            mni.printing.bdf.writeColumnDelimiter(fid, "short")
            for i = 1:length(obj)
                Pa = obj(i).Stations(1).Point;
                Pb = obj(i).Stations(end).Point;
                if ~isempty(obj(i).G0)
                    tmpCard = mni.printing.cards.CBEAM( ...
                        obj(i).ID, obj(i).PID, Pa.ID, Pb.ID, "G0", obj(i).G0.ID);
                else
                    tmpCard = mni.printing.cards.CBEAM( ...
                        obj(i).ID, obj(i).PID, Pa.ID, Pb.ID, "x", obj(i).yDir);
                end
                tmpCard.writeToFile(fid);
            end

            % --- PBEAML cards ----------------------------------------
            mni.printing.bdf.writeComment(fid, ...
                "PBEAML : Beam cross-section from the MSCBML0 library.");
            mni.printing.bdf.writeColumnDelimiter(fid, "short")
            for i = 1:length(obj)
                if obj(i).Type == ""
                    error('ads.fe.LBeam(%d): Type must be set before export.', i);
                end
                Xa = obj(i).Stations(1).Point.X;
                Xb = obj(i).Stations(end).Point.X;

                nSec = length(obj(i).Stations);
                Sections = repmat( ...
                    struct('DIM', [], 'NSM', 0, 'SO', 'YES', 'X', 0), nSec, 1);
                for j = 1:nSec
                    Sections(j) = obj(i).Stations(j).ToMatranSection(Xa, Xb);
                end

                tmpCard = mni.printing.cards.PBEAML( ...
                    obj(i).PID, obj(i).Stations(1).Mat.ID, ...
                    obj(i).Type, Sections, GROUP = obj(i).Group);
                tmpCard.LongFormat = obj(i).ExportLongFormat;
                tmpCard.writeToFile(fid);
            end
        end

        function EIDs = EIDfromEta(obj, eta)
            % Same logic as ads.fe.Beam.EIDfromEta. Returns 2×N matrix:
            % rows identical unless eta lies on a station boundary, in
            % which case row 1 = inboard element ID, row 2 = outboard.
            wingStations = [obj.Stations];
            stationEtas  = [[wingStations(1,:).eta]; [wingStations(2,:).eta]];

            numQueries = length(eta);
            EIDs = nan(2, numQueries);

            for i = 1:numQueries
                shifted    = stationEtas - eta(i);
                outbdMask  = shifted > 0;
                inbdMask   = shifted < 0;
                exactMask  = shifted == 0;
                outOfRange = all(outbdMask, 'all') || all(inbdMask, 'all');

                if any(exactMask, 'all')
                    if any(exactMask(1,:), 'all')
                        EIDs(2,i) = obj(exactMask(1,:)).ID;
                    end
                    if any(exactMask(2,:), 'all')
                        EIDs(1,i) = obj(exactMask(2,:)).ID;
                    end
                elseif ~outOfRange
                    containsMask = outbdMask(1,:) ~= outbdMask(2,:);
                    EIDs(1,i) = obj(containsMask).ID;
                    EIDs(2,i) = obj(containsMask).ID;
                end
            end
        end

        function order = getEtaOrder(obj)
            wingStations = [obj.Stations];
            startEtas    = [wingStations(1,:).eta];
            [~, order]   = sort(startEtas);
        end
    end

    methods(Static)
        function n = NumDimsForType(type)
            %NUMDIMSFORTYPE PBEAML TYPE -> number of DIM entries.
            switch upper(string(type))
                case "ROD",   n = 1;
                case "TUBE",  n = 2;
                case "TUBE2", n = 2;
                case "L",     n = 4;
                case "I",     n = 6;
                case "CHAN",  n = 4;
                case "T",     n = 4;
                case "BOX",   n = 4;
                case "BAR",   n = 2;
                case "CROSS", n = 4;
                case "H",     n = 4;
                case "T1",    n = 4;
                case "I1",    n = 4;
                case "CHAN1", n = 4;
                case "Z",     n = 4;
                case "CHAN2", n = 4;
                case "T2",    n = 4;
                case "BOX1",  n = 6;
                case "HEXA",  n = 3;
                case "HAT",   n = 4;
                case "HAT1",  n = 5;
                case "DBOX",  n = 10;
                otherwise
                    error('ads.fe.LBeam.NumDimsForType: unknown PBEAML TYPE "%s".', type);
            end
        end

        function A = AreaFromTypeDIM(type, DIM)
            %AREAFROMTYPEDIM Analytic cross-section area for the
            %   PBEAML TYPEs the baff LBeam factories build. Add cases
            %   here if you start using more shapes from the library.
            switch upper(string(type))
                case "ROD"
                    A = pi * DIM(1)^2;
                case {"TUBE", "TUBE2"}
                    A = pi * (DIM(1)^2 - DIM(2)^2);
                case "BAR"
                    A = DIM(1) * DIM(2);
                case "BOX"
                    w = DIM(1); h = DIM(2); tT = DIM(3); tL = DIM(4);
                    A = w*h - (w - 2*tL)*(h - 2*tT);
                case "L"
                    leg_h = DIM(1); leg_v = DIM(2); t_w = DIM(3); t_f = DIM(4);
                    A = leg_h*t_f + (leg_v - t_f)*t_w;
                case "Z"
                    fw = DIM(1); tw = DIM(2); tf = DIM(3); h = DIM(4);
                    A = 2*fw*tf + (h - 2*tf)*tw;
                case "HAT"
                    h = DIM(1); t = DIM(2); crown = DIM(3); brim = DIM(4);
                    A = t * (crown + 2*(h - t) + 2*brim);   % thin-walled approx
                otherwise
                    error('ads.fe.LBeam.AreaFromTypeDIM: not implemented for TYPE "%s".', type);
            end
        end

        function obj = FromBaffLBeamSegment(baff_lbeam, station_indices, points, Mat)
            %FROMBAFFLBEAMSEGMENT One ads.fe.LBeam from a 2-station slice
            %of a baff.station.LBeam. Cross-section TYPE and per-station
            %DIM/NSM/SO are inherited; yDir is taken from the segment's
            %first station's StationDir.
            arguments
                baff_lbeam      (1,1) baff.station.LBeam
                station_indices (1,2) double
                points          (2,1) ads.fe.Point
                Mat             ads.fe.Material
            end
            sa = baff_lbeam.GetIndex(station_indices(1));
            sb = baff_lbeam.GetIndex(station_indices(2));
            s1 = ads.fe.LBeamStation.FromBaffStation(sa, points(1), Mat);
            s2 = ads.fe.LBeamStation.FromBaffStation(sb, points(2), Mat);
            yDir = sa.StationDir;
            obj  = ads.fe.LBeam([s1; s2], ...
                yDir  = yDir, ...
                Type  = baff_lbeam.Type);
        end

        function objs = FromBaffLBeam(baff_lbeam, points, Mat)
            %FROMBAFFLBEAM Build (N-1) ads.fe.LBeam objects from an
            %N-station baff LBeam. The supplied points are the ads.fe.Points
            %the stringer shares with the rest of the mesh — one per
            %baff station, in order.
            arguments
                baff_lbeam (1,1) baff.station.LBeam
                points     (:,1) ads.fe.Point
                Mat        ads.fe.Material
            end
            N = baff_lbeam.N;
            if length(points) ~= N
                error('ads.fe.LBeam.FromBaffLBeam: expected %d points (one per baff station), got %d.', ...
                    N, length(points));
            end
            if N < 2
                error('ads.fe.LBeam.FromBaffLBeam: need at least 2 stations to form a beam.');
            end
            objs = ads.fe.LBeam.empty;
            for k = 1:N-1
                objs(k) = ads.fe.LBeam.FromBaffLBeamSegment( ...
                    baff_lbeam, [k, k+1], points([k; k+1]), Mat); %#ok<AGROW>
            end
        end
    end
end