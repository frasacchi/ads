classdef LBeamStation
    %LBEAMSTATION Single station of an ads.fe.LBeam (PBEAML cross-section).
    %   Mirrors ads.fe.BeamStation but carries the PBEAML per-station data
    %   (DIM column, NSM, SO) instead of analytic section properties
    %   (A, I, J). The PBEAML cross-section TYPE itself is constant along
    %   the beam and lives on ads.fe.LBeam. PBEAML has no per-station
    %   stress-recovery points — those are baked into the library section
    %   shapes — so the C/D/E/F properties from BeamStation are absent.

    properties
        Point ads.fe.Point
        Mat ads.fe.Material = ads.fe.Material.Aluminium;
        DIM (:,1) double = []          % cross-section dimensions for this station
        NSM (1,1) double = 0           % non-structural mass per length
        SO  (1,1) string = "YES"       % stress output request
        eta = NaN;                     % spanwise parameter; set externally (mirrors BeamStation)
    end

    methods
        function obj = LBeamStation(Point, opts)
            arguments
                Point ads.fe.Point
                opts.Mat ads.fe.Material = ads.fe.Material.Aluminium
                opts.DIM (:,1) double = []
                opts.NSM (1,1) double = 0
                opts.SO  (1,1) string = "YES"
            end
            obj.Point = Point;
            obj.Mat   = opts.Mat;
            obj.DIM   = opts.DIM;
            obj.NSM   = opts.NSM;
            obj.SO    = opts.SO;
        end

        function sec = ToMatranSection(obj, startPoint, endPoint)
            %TOMATRANSECTION Build a PBEAML section for this station.
            %
            %   Signature matches BeamStation.ToMatranSection: startPoint
            %   and endPoint are 3-vectors (i.e. ads.fe.Point.X values),
            %   not Point objects. The station's X/XB ratio is computed
            %   by projecting this station's Point onto the End A → End B
            %   axis and rounded to 10 dp to absorb floating-point noise
            %   (matran's PBEAML.writeToFile checks the last section has
            %   X == 1.0 strictly).
            %
            %   NOTE: if your matran fork exposes a PBEAML section class
            %   (parallel to mni.printing.cards.BeamSection for PBEAM —
            %   e.g. BeamLSection), swap the struct return for that class.
            X = dot(endPoint - startPoint, obj.Point.X - startPoint) / norm(endPoint - startPoint)^2;
            X = round(X, 10);   % match BeamStation's FP-noise handling
            sec.DIM = obj.DIM(:).';
            sec.NSM = obj.NSM;
            sec.SO  = char(obj.SO);
            sec.X   = X;
        end
    end

    methods(Static)
        function obj = FromBaffStation(st, Point, Mat)
            %FROMBAFFSTATION Build from a *single-station* baff LBeam.
            %   Caller extracts the scalar station via baff_lbeam.GetIndex(i)
            %   exactly as BeamStation.FromBaffStation does with baff Beam.
            arguments
                st    (1,1) baff.station.LBeam
                Point       ads.fe.Point
                Mat         ads.fe.Material
            end
            obj = ads.fe.LBeamStation(Point, ...
                Mat = Mat, ...
                DIM = st.DIM, ...
                NSM = st.NSM);
            % SO is not tracked on baff.station.LBeam — its PBEAML exporter
            % hard-codes 'YES' for every station, so we let the LBeamStation
            % default ("YES") flow through unchanged.
            obj.eta = st.Eta;
        end
    end
end