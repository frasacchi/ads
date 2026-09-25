function card = eigCard(id,method,freqRange,nd,norm)
%EIGCARD Eigen solver card: EIGRL for method 'LAN', otherwise EIGR.
%   The frequency range [0,freqRange(2)] (V2 for EIGRL, F1/F2 for EIGR) and
%   ND are omitted when empty.
args = {};
if strcmpi(method,'LAN')
    if ~isempty(freqRange)
        args = [args,{'V2',freqRange(2)}];
    end
    if ~isempty(nd)
        args = [args,{'ND',nd}];
    end
    if ~isempty(norm)
        args = [args,{'NORM',norm}];
    end
    card = mni.printing.cards.EIGRL(id,args{:});
else
    if ~isempty(freqRange)
        args = [args,{'F1',0,'F2',freqRange(2)}];
    end
    if ~isempty(nd)
        args = [args,{'ND',nd}];
    end
    if ~isempty(norm)
        args = [args,{'NORM',norm}];
    end
    card = mni.printing.cards.EIGR(id,method,args{:});
end
end
