function varargout = title(str,opts)
    arguments
        str char
        opts.fid = 1;
        opts.Length = 80;
        opts.Symbol string = "-"
        opts.Padding = 0
    end
    
    if length(str)>=opts.Length
        % no nothing
    elseif length(str) == opts.Length-1
        str = [' ',str];
    elseif length(str) == opts.Length-2
        str = [' ',str,' '];
    elseif length(str) == opts.Length-3
        str = ['- ',str,' '];
    else
        delta = opts.Length-(length(str)+2);
        dashes = repmat(char(opts.Symbol(1)),1,floor(delta/2));
        if length(opts.Symbol) > 1
            dashes_2 = repmat(char(opts.Symbol(2)),1,floor(delta/2));
        else
            dashes_2 = dashes;
        end

        if mod(delta,2) == 0
            str = [dashes,' ',str,' ',dashes_2];
        else
            str = [dashes,' ',str,' ',dashes_2(1),dashes_2];
        end
    end
    padding = '';
    for i = 1:opts.Padding
        padding = [padding,repmat(char(opts.Symbol(1)),1,floor(opts.Length/2)),...
            repmat(char(opts.Symbol(2)),1,ceil(opts.Length/2)),'\n'];
    end
    fprintf(opts.fid,[padding,str,'\n',padding]);
    if nargout>0
        varargout{1} = str;
    end
    end    