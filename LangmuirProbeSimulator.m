function LangmuirProbeSimulator
% LANGMUIRPROBESIMULATOR Langmuir probe stray-capacitance compensation simulator.
%
% Description:
%   Educational MATLAB simulator for a Langmuir probe with stray capacitance.
%   It compares continuous voltage sweep and stepped voltage sweep with RC
%   settling time. The main thesis idea is to convert the stray-capacitor
%   displacement current from a continuous measurement error into a short,
%   manageable transient by waiting on each voltage step.
%
% License:
%   MIT License
%
%   Copyright (c) 2026 Amirerfan Bohlouli
%   Contact: https://github.com/amirerfanx
%   Email: Amirerfanbohlouli@gmail.com
%
%   Permission is hereby granted, free of charge, to any person obtaining a copy
%   of this software and associated documentation files (the "Software"), to deal
%   in the Software without restriction, including without limitation the rights
%   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%   copies of the Software, and to permit persons to whom the Software is
%   furnished to do so, subject to the following conditions:
%
%   The above copyright notice and this permission notice shall be included in all
%   copies or substantial portions of the Software.
%
%   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%   SOFTWARE.

    fontName = 'Segoe UI';
    if ismac
        fontName = 'Helvetica';
    end

    % --- fixed sweep range ---
    V_MIN = -30;
    V_MAX =  30;

    app = struct();
    app.running = false;
    app.params = struct( ...
        'Te', 4.0, ...          % electron temperature [eV]
        'ne', 2.0, ...          % relative density [a.u.]
        'tau', 5.0, ...         % RC time constant [us]
        'dwellTau', 5.0, ...    % settling time, in units of tau
        'Cstray', 8.0, ...      % stray capacitance coefficient [a.u.]
        'noise', 0.008, ...     % measurement noise amplitude [a.u.]
        'speed', 2.0);          % just controls animation speed

    app.ui = struct();

    set(0, 'DefaultUicontrolFontName', fontName, 'DefaultUicontrolFontSize', 10);
    set(0, 'DefaultAxesFontName', fontName, 'DefaultAxesFontSize', 10);

    fig = figure( ...
        'Name', 'Langmuir Probe Simulator', ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.05 0.94 0.85], ...
        'Color', [0.98 0.98 0.99], ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'on');

    leftPanel = uipanel('Parent', fig, 'Title', 'Controls', ...
        'Units', 'normalized', 'Position', [0.01 0.05 0.27 0.90], ...
        'FontName', fontName, 'FontSize', 11, 'FontWeight', 'bold');

    rightPanel = uipanel('Parent', fig, 'Title', 'Simulation Results', ...
        'Units', 'normalized', 'Position', [0.29 0.05 0.70 0.90], ...
        'FontName', fontName, 'FontSize', 11, 'FontWeight', 'bold');

    leftColor = get(leftPanel, 'BackgroundColor');
    rightColor = get(rightPanel, 'BackgroundColor');

    uicontrol('Parent', leftPanel, 'Style', 'edit', 'Max', 2, 'Enable', 'inactive', ...
        'String', {['Idea: the stray capacitor turns a continuous sweep''s ' ...
                     'displacement current into a constant offset error. ' ...
                     'Stepping the voltage and waiting ~5*tau before each ' ...
                     'sample lets that transient decay first, so you sample ' ...
                     'closer to the true plasma current.']}, ...
        'Units', 'normalized', 'Position', [0.03, 0.855, 0.94, 0.125], ...
        'FontName', fontName, 'FontSize', 9, ...
        'BackgroundColor', [1.0 1.0 0.95], 'HorizontalAlignment', 'left');

    % sliders — added Cstray and noise since those are the two knobs
    % that actually matter for the compensation story
    makeSliderRow(0.795, 'Te (eV)',      0.5, 10.0, app.params.Te,      'Te',      '%.1f');
    makeSliderRow(0.750, 'ne (rel.)',    0.1, 5.0,  app.params.ne,      'ne',      '%.1f');
    makeSliderRow(0.705, 'tau (us)',     0.5, 20.0, app.params.tau,     'tau',     '%.1f');
    makeSliderRow(0.660, 'Dwell (xtau)', 0.0, 10.0, app.params.dwellTau,'dwellTau','%.1f');
    makeSliderRow(0.615, 'Cstray',       0.5, 20.0, app.params.Cstray,  'Cstray',  '%.1f');
    makeSliderRow(0.570, 'Noise',        0.0, 0.05, app.params.noise,  'noise',   '%.3f');
    makeSliderRow(0.525, 'Speed',        0.5, 5.0,  app.params.speed,  'speed',   '%.1f');

    app.ui.btnContinuous = uicontrol('Parent', leftPanel, 'Style', 'pushbutton', ...
        'String', 'Continuous Sweep (No Settling)', ...
        'Units', 'normalized', 'Position', [0.03, 0.465, 0.94, 0.050], ...
        'FontName', fontName, 'FontSize', 10, 'BackgroundColor', [0.90 0.90 0.98], ...
        'Callback', @(~,~) runContinuous());

    app.ui.btnStepped = uicontrol('Parent', leftPanel, 'Style', 'pushbutton', ...
        'String', 'Stepped Sweep (With Settling)', ...
        'Units', 'normalized', 'Position', [0.03, 0.405, 0.94, 0.050], ...
        'FontName', fontName, 'FontSize', 10, 'BackgroundColor', [0.90 0.98 0.90], ...
        'Callback', @(~,~) runStepped());

    app.ui.btnClear = uicontrol('Parent', leftPanel, 'Style', 'pushbutton', ...
        'String', 'Clear / Reset Plots', ...
        'Units', 'normalized', 'Position', [0.03, 0.345, 0.94, 0.050], ...
        'FontName', fontName, 'FontSize', 10, 'BackgroundColor', [0.98 0.92 0.92], ...
        'Callback', @(~,~) clearAll());

    uicontrol('Parent', leftPanel, 'Style', 'text', 'String', 'Results', ...
        'Units', 'normalized', 'Position', [0.03, 0.300, 0.94, 0.035], ...
        'FontName', fontName, 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', leftColor);

    app.lblTeTrue = uicontrol('Parent', leftPanel, 'Style', 'text', ...
        'String', sprintf('Te input: %.2f eV', app.params.Te), ...
        'Units', 'normalized', 'Position', [0.03, 0.263, 0.94, 0.032], ...
        'FontName', fontName, 'FontSize', 10, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', leftColor);

    app.lblTeCont = uicontrol('Parent', leftPanel, 'Style', 'text', ...
        'String', 'Te estimated (continuous): -', ...
        'Units', 'normalized', 'Position', [0.03, 0.228, 0.94, 0.032], ...
        'FontName', fontName, 'FontSize', 10, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', leftColor);

    app.lblTeStep = uicontrol('Parent', leftPanel, 'Style', 'text', ...
        'String', 'Te estimated (stepped): -', ...
        'Units', 'normalized', 'Position', [0.03, 0.193, 0.94, 0.032], ...
        'FontName', fontName, 'FontSize', 10, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', leftColor);

    app.lblErrCont = uicontrol('Parent', leftPanel, 'Style', 'text', ...
        'String', 'Error (continuous): -', ...
        'Units', 'normalized', 'Position', [0.03, 0.158, 0.94, 0.032], ...
        'FontName', fontName, 'FontSize', 9, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', leftColor, ...
        'ForegroundColor', [0.6 0.1 0.1]);

    app.lblErrStep = uicontrol('Parent', leftPanel, 'Style', 'text', ...
        'String', 'Error (stepped): -', ...
        'Units', 'normalized', 'Position', [0.03, 0.123, 0.94, 0.032], ...
        'FontName', fontName, 'FontSize', 9, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', leftColor, ...
        'ForegroundColor', [0.1 0.4 0.1]);

    uicontrol('Parent', leftPanel, 'Style', 'edit', 'Max', 3, 'Enable', 'inactive', ...
        'String', {'MIT License. Copyright (c) 2026 Amirerfan Bohlouli.', ...
                    'Contact: github.com/amirerfanx | Amirerfanbohlouli@gmail.com', ...
                    'Free to use, copy, modify and distribute for academic and personal projects.'}, ...
        'Units', 'normalized', 'Position', [0.03, 0.02, 0.94, 0.095], ...
        'FontName', fontName, 'FontSize', 8, ...
        'BackgroundColor', [0.97 0.97 0.97], 'HorizontalAlignment', 'left');

    % --- right panel: plots ---
    uicontrol('Parent', rightPanel, 'Style', 'text', 'String', 'I-V Characteristic', ...
        'Units', 'normalized', 'Position', [0.05, 0.94, 0.90, 0.04], ...
        'FontName', fontName, 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', rightColor);

    app.axIV = axes('Parent', rightPanel, 'Units', 'normalized', ...
        'Position', [0.09, 0.56, 0.86, 0.36], 'Color', [1 1 1]);
    set(app.axIV, 'FontName', fontName, 'FontSize', 10);

    uicontrol('Parent', rightPanel, 'Style', 'text', ...
        'String', 'Stray-Capacitor Displacement Current', ...
        'Units', 'normalized', 'Position', [0.05, 0.49, 0.90, 0.04], ...
        'FontName', fontName, 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', rightColor);

    app.axTrans = axes('Parent', rightPanel, 'Units', 'normalized', ...
        'Position', [0.09, 0.09, 0.86, 0.36], 'Color', [1 1 1]);
    set(app.axTrans, 'FontName', fontName, 'FontSize', 10);

    app.status = uicontrol('Parent', fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.01, 0.01, 0.98, 0.03], ...
        'String', 'Ready. Set parameters and run a sweep.', ...
        'FontName', fontName, 'FontSize', 10, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', get(fig, 'Color'));

    % ================================================================
    %  nested functions
    % ================================================================

    function makeSliderRow(yPos, labelText, minVal, maxVal, initVal, fieldName, fmt)
        uicontrol('Parent', leftPanel, 'Style', 'text', 'String', labelText, ...
            'Units', 'normalized', 'Position', [0.03, yPos, 0.30, 0.04], ...
            'FontName', fontName, 'FontSize', 10, ...
            'HorizontalAlignment', 'left', 'BackgroundColor', leftColor);

        hVal = uicontrol('Parent', leftPanel, 'Style', 'text', ...
            'String', sprintf(fmt, initVal), ...
            'Units', 'normalized', 'Position', [0.84, yPos, 0.13, 0.04], ...
            'FontName', fontName, 'FontSize', 10, ...
            'HorizontalAlignment', 'right', 'BackgroundColor', leftColor);

        hSlider = uicontrol('Parent', leftPanel, 'Style', 'slider', ...
            'Min', minVal, 'Max', maxVal, 'Value', initVal, ...
            'Units', 'normalized', 'Position', [0.34, yPos + 0.006, 0.48, 0.030], ...
            'BackgroundColor', [0.80 0.80 0.80]);

        set(hSlider, 'Callback', @(src, evt) sliderCallback(src, evt, fieldName, hVal, fmt));
    end

    function sliderCallback(src, ~, fieldName, valueHandle, fmt)
        val = get(src, 'Value');
        app.params.(fieldName) = val;
        set(valueHandle, 'String', sprintf(fmt, val));

        if strcmp(fieldName, 'Te')
            set(app.lblTeTrue, 'String', sprintf('Te input: %.2f eV', val));
        end

        invalidatePlots();
    end

    function invalidatePlots()
        if ishandle(app.axIV), cla(app.axIV); end
        if ishandle(app.axTrans), cla(app.axTrans); end
        set(app.lblTeCont, 'String', 'Te estimated (continuous): -');
        set(app.lblTeStep, 'String', 'Te estimated (stepped): -');
        set(app.lblErrCont, 'String', 'Error (continuous): -');
        set(app.lblErrStep, 'String', 'Error (stepped): -');
        set(app.status, 'String', 'Parameters changed. Run a sweep.');
    end

    function clearAll()
        if ishandle(app.axIV), cla(app.axIV); end
        if ishandle(app.axTrans), cla(app.axTrans); end
        set(app.lblTeCont, 'String', 'Te estimated (continuous): -');
        set(app.lblTeStep, 'String', 'Te estimated (stepped): -');
        set(app.lblErrCont, 'String', 'Error (continuous): -');
        set(app.lblErrStep, 'String', 'Error (stepped): -');
        set(app.status, 'String', 'Ready. Set parameters and run a sweep.');
    end

    function ensureAxes()
        if ~ishandle(app.axIV), return; end
        hold(app.axIV, 'on');

        hTrue = findobj(app.axIV, 'Tag', 'trueCurve');
        if isempty(hTrue)
            V = linspace(V_MIN, V_MAX, 900);
            I = plasmaCurrent(V, app.params.Te, app.params.ne);

            plot(app.axIV, V, I, 'k--', 'LineWidth', 2.0, ...
                'Tag', 'trueCurve', 'DisplayName', 'True plasma curve');

            xlabel(app.axIV, 'Probe voltage (V)', 'FontName', fontName, 'FontSize', 11);
            ylabel(app.axIV, 'Current (a.u.)', 'FontName', fontName, 'FontSize', 11);
            title(app.axIV, 'Langmuir Probe I-V Characteristic', 'FontName', fontName, 'FontSize', 12);

            grid(app.axIV, 'on');
            box(app.axIV, 'on');
            set(app.axIV, 'XLim', [V_MIN, V_MAX]);
        end
    end

    function deleteLineByTag(tag)
        h = findobj(app.axIV, 'Tag', tag);
        delete(h);
    end

    function updateLegend()
        hLines = findobj(app.axIV, 'Type', 'Line');
        if ~isempty(hLines)
            legend(app.axIV, 'show', 'Location', 'best', 'FontName', fontName, 'FontSize', 9);
        else
            legend(app.axIV, 'off');
        end
    end

    function runContinuous()
        if app.running, return; end
        app.running = true;

        try
            p = app.params;
            ensureAxes();
            deleteLineByTag('continuousCurve');

            V = linspace(V_MIN, V_MAX, 700);
            Itrue = plasmaCurrent(V, p.Te, p.ne);

            Ttotal_us = 2500 / max(p.speed, 0.1);
            t = linspace(0, Ttotal_us, numel(V));
            dVdt = (V_MAX - V_MIN) / Ttotal_us;

            % constant displacement current riding on top of the real signal
            Idisp = p.Cstray * dVdt * ones(size(V));
            Imeas = Itrue + Idisp + p.noise * randn(size(V));

            hCont = plot(app.axIV, nan, nan, 'r-', 'LineWidth', 2.0, ...
                'Tag', 'continuousCurve', 'DisplayName', 'Continuous sweep (no settling)');
            updateLegend();

            if ishandle(app.axTrans), cla(app.axTrans); end
            hTrans = plot(app.axTrans, nan, nan, 'Color', [0.00 0.45 0.74], 'LineWidth', 2.0);

            xlabel(app.axTrans, 'Time (us)', 'FontName', fontName, 'FontSize', 11);
            ylabel(app.axTrans, 'Displacement current (a.u.)', 'FontName', fontName, 'FontSize', 11);
            title(app.axTrans, 'Continuous stray-capacitor displacement current', 'FontName', fontName, 'FontSize', 12);

            grid(app.axTrans, 'on');
            box(app.axTrans, 'on');
            xlim(app.axTrans, [0, Ttotal_us]);

            ylimMax = max(1.2 * max(abs(Idisp)), 0.1);
            ylim(app.axTrans, [-ylimMax, ylimMax]);

            n = numel(V);
            chunk = max(1, round(n / 60));   % ~60 redraw steps regardless of point count
            animSeconds = 2.0 / max(p.speed, 0.1);
            delay = animSeconds * chunk / n;

            for k = 1:chunk:n
                if ~ishandle(hCont) || ~ishandle(hTrans)
                    app.running = false;
                    return;
                end

                idx = 1:min(k, n);
                set(hCont, 'XData', V(idx), 'YData', Imeas(idx));
                set(hTrans, 'XData', t(idx), 'YData', Idisp(idx));

                drawnow limitrate;
                pause(delay);
            end

            set(hCont, 'XData', V, 'YData', Imeas);
            set(hTrans, 'XData', t, 'YData', Idisp);

            TeCont = estimateTe(V, Imeas);
            reportResult(app.lblTeCont, app.lblErrCont, 'continuous', TeCont, p.Te);

        catch ME
            set(app.status, 'String', ['Error: ' ME.message]);
        end

        app.running = false;
    end

    function runStepped()
        if app.running, return; end
        app.running = true;

        try
            p = app.params;
            ensureAxes();
            deleteLineByTag('steppedCurve');

            N = 81;
            Vsteps = linspace(V_MIN, V_MAX, N);
            stepV = (V_MAX - V_MIN) / (N - 1);
            dwell_us = p.dwellTau * p.tau;

            Imeas = nan(size(Vsteps));

            hStep = plot(app.axIV, nan, nan, 'b-o', 'LineWidth', 1.6, ...
                'MarkerSize', 3.5, 'MarkerFaceColor', 'b', ...
                'Tag', 'steppedCurve', 'DisplayName', 'Stepped sweep (with settling)');
            updateLegend();

            prevV = V_MIN;
            animDelay = 0.025 / max(p.speed, 0.1);

            for k = 1:N
                if ~ishandle(hStep)
                    app.running = false;
                    return;
                end

                V = Vsteps(k);
                dV = V - prevV;

                if p.tau <= 0
                    residual = 0;
                else
                    peak = p.Cstray * dV / p.tau;
                    residual = peak * exp(-dwell_us / p.tau);
                end

                Imeas(k) = plasmaCurrent(V, p.Te, p.ne) + residual + p.noise * randn();

                set(hStep, 'XData', Vsteps(1:k), 'YData', Imeas(1:k));
                drawnow limitrate;
                pause(animDelay);

                prevV = V;
            end

            TeStep = estimateTe(Vsteps, Imeas);
            reportResult(app.lblTeStep, app.lblErrStep, 'stepped', TeStep, p.Te);

            % transient plot for one representative step
            if ishandle(app.axTrans), cla(app.axTrans); end

            if p.tau > 0
                tEnd = max([12 * p.tau, 1.2 * dwell_us, 1.0]);
                tt = linspace(0, tEnd, 800);

                peakRep = p.Cstray * stepV / p.tau;
                It = peakRep * exp(-tt / p.tau);

                plot(app.axTrans, tt, It, 'Color', [0.85 0.33 0.10], 'LineWidth', 2.0);
                hold(app.axTrans, 'on');

                xlabel(app.axTrans, 'Time (us)', 'FontName', fontName, 'FontSize', 11);
                ylabel(app.axTrans, 'Capacitive transient current (a.u.)', 'FontName', fontName, 'FontSize', 11);
                title(app.axTrans, sprintf('Transient for one voltage step (dwell = %.1f x tau)', p.dwellTau), ...
                    'FontName', fontName, 'FontSize', 12);

                grid(app.axTrans, 'on');
                box(app.axTrans, 'on');
                xlim(app.axTrans, [0, tEnd]);

                yMin = min(It) - 0.15 * abs(peakRep);
                yMax = max(It) + 0.15 * abs(peakRep);
                if yMax <= yMin, yMax = yMin + 1.0; end
                ylim(app.axTrans, [yMin, yMax]);

                plot(app.axTrans, [dwell_us, dwell_us], [yMin, yMax], 'k--', 'LineWidth', 1.6);

                textX = max(dwell_us, 0.03 * tEnd);
                textY = yMax - 0.12 * (yMax - yMin);
                text(app.axTrans, textX, textY, sprintf('Sampling at %.1f x tau', p.dwellTau), ...
                    'FontName', fontName, 'FontSize', 10, 'Interpreter', 'none');
            end

        catch ME
            set(app.status, 'String', ['Error: ' ME.message]);
        end

        app.running = false;
    end

    function reportResult(lblTe, lblErr, label, TeEst, TeTrue)
        if isnan(TeEst)
            set(lblTe, 'String', sprintf('Te estimated (%s): fit failed', label));
            set(lblErr, 'String', sprintf('Error (%s): -', label));
            set(app.status, 'String', sprintf('%s sweep finished. Fit did not converge — try lower noise or a wider dwell.', label));
        else
            errPct = 100 * (TeEst - TeTrue) / TeTrue;
            set(lblTe, 'String', sprintf('Te estimated (%s): %.2f eV', label, TeEst));
            set(lblErr, 'String', sprintf('Error (%s): %+.1f%%', label, errPct));
            set(app.status, 'String', sprintf('%s sweep finished. Estimated Te = %.2f eV (%+.1f%% vs input).', ...
                label, TeEst, errPct));
        end
    end

    function I = plasmaCurrent(V, Te, ne)
        % Simple exponential-electron-current / near-constant-ion-current
        % Langmuir model. Arbitrary units, chosen just to make the demo legible.
        Vp = 0;
        Ie_sat = 1.0;
        Ii_sat = 0.015;

        Veff = min(V, Vp);
        I = ne .* (Ie_sat .* exp(Veff ./ Te) + Ii_sat);
    end

    function Te = estimateTe(V, I)
        % Fits log(I) vs V in the electron-retardation region to recover Te.
        % Picks the fit window adaptively and falls back to a wider window
        % if the strict one doesn't leave enough points (this matters a lot
        % once noise or a leftover capacitive transient is added on top).
        V = V(:);
        I = I(:);

        ok = isfinite(V) & isfinite(I) & (I > 0);
        V = V(ok);
        I = I(ok);

        if numel(V) < 10
            Te = NaN;
            return;
        end

        Imin = min(I);
        Imax = max(I);
        if Imax <= Imin
            Te = NaN;
            return;
        end

        % try a sequence of progressively looser windows instead of one
        % fixed band — a single hardcoded window breaks as soon as the
        % signal is noisy or offset by a residual transient
        windows = [0.10 0.85; 0.05 0.90; 0.02 0.95];
        Te = NaN;

        for w = 1:size(windows, 1)
            lo = Imin + windows(w,1) * (Imax - Imin);
            hi = Imin + windows(w,2) * (Imax - Imin);
            idx = (V < -0.5) & (I > lo) & (I < hi);

            if sum(idx) >= 8 && (max(I(idx)) - min(I(idx))) > 1e-12
                TeCandidate = fitTe(V(idx), I(idx));
                if isfinite(TeCandidate) && TeCandidate > 0 && TeCandidate < 100
                    Te = TeCandidate;
                    break;
                end
            end
        end

        % last resort: use every point below the plasma potential with
        % positive current, unweighted
        if isnan(Te)
            idx = (V < -0.5) & (I > 0);
            if sum(idx) >= 5
                TeCandidate = fitTe(V(idx), I(idx));
                if isfinite(TeCandidate) && TeCandidate > 0 && TeCandidate < 100
                    Te = TeCandidate;
                end
            end
        end
    end

    function Te = fitTe(V, I)
        try
            p = polyfit(V, log(I), 1);
            if p(1) > 0
                Te = 1 / p(1);
            else
                Te = NaN;
            end
        catch
            Te = NaN;
        end
    end
end
