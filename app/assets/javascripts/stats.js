
function getDateTZ(json, offset) {
  d = new Date(json);
  utc = d.getTime() + (d.getTimezoneOffset() * 60000);
  nd = new Date(utc + (offset*1000));
  return nd;
}

function getData(remote_url, chart, data, options, params, offset) {
  $.ajax({
    type:"get",
    url: remote_url,
    data: params,
    contentType: "application/json"
  })
  .done(function(json){
    if (json.data.length > 0) {
      console.log("Request successful!", json);
      data.addRows(json.data);
      options['title'] += ' - Last update ' + getDateTZ(json.last_update, offset).toLocaleTimeString();
      chart.draw(data, options);
    }
  });
}

function drawRealTimeChart(remote_url, elementId, timeInterval, offset) {

  if ($("#" + elementId).length == 0 || timeInterval == null || timeInterval <= 0)
    return;

  // Create the data table.
  var data = new google.visualization.DataTable();
  data.addColumn('datetime', 'Time');
  data.addColumn('number', 'Power');

  // Set chart options
  var options = {
    'title':'Real Time Power Usage (Watt)', 
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},    
    legend: 'none',
    }//,
/*        'width':400,
  'height':300};
  */
  // Instantiate and draw our chart, passing in some options.
  var chart = new google.visualization.LineChart(document.getElementById(elementId));
  window.evLsn = google.visualization.events.addListener(chart, 'ready', function() {
    if (data.getNumberOfRows() > 0)
      $("#chart_real_time_control").removeClass("hidden");
    $("#set-real-time-interval").prop('disabled', false);
    // console.log('visible' + $("#chart_real_time_control"));
    google.visualization.events.removeListener(window.evLsn);
  });

  t = new Date();
  t.setMinutes(t.getMinutes() - timeInterval);
  loadRealTimeData(remote_url, chart, data, options, timeInterval, t, elementId, offset);

  if (window.realTimeIntervalId)
    clearInterval(window.realTimeIntervalId);
  window.realTimeIntervalId = setInterval(loadRealTimeData.bind(null, remote_url, chart, data, options, timeInterval, null, elementId, offset), 1000 * 5);
}

function loadRealTimeData(remote_url, chart, data, options, timeInterval, time, elementId, offset) {
  if (time == null) {
    time = new Date();
    time.setSeconds(time.getSeconds() - 5);
  }
  timeLimit = new Date();
  timeLimit.setMinutes(timeLimit.getMinutes() - timeInterval);

  var req = $.ajax({
    type:"get",
    url: remote_url,
    data:{ time: time },
    timeout: 5000,
    contentType: "application/json"
  })
  .done(function(json){
    if (json.length > 0) {
      for(j = 0; j < json.length; j++) {
        json[j][0] = getDateTZ(json[j][0], offset);
      }
      // console.log("Request successful!", json);
      while(data.getNumberOfRows() > 10 && data.getValue(0, 0) < timeLimit) data.removeRow(0); 
      data.addRows(json);
      chart.draw(data, options);            
    }
    if ($("#" + elementId).length == 0) {
      clearInterval(window.realTimeIntervalId);
    }
  });
}

function drawWeeklyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Weekly Power Usage (Watt/day)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    // ,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('string', 'Day of the week');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last 7 days');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last 7 days Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options, { force: window.forceRefresh == true }, offset);
}

function drawDailyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Daily Power Usage (Watt/hour)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    //,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('number', 'Hour');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last Day');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last Day Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options, { force: window.forceRefresh == true }, offset);
}

function drawMonthlyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Monthly Power Usage (Watt/day)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    //,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('number', 'Day');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last Month');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last Month Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options, { force: window.forceRefresh == true }, offset);
}


function drawYearlyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Yearly Power Usage (Watt/month)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    // ,chartArea: { width: '90%', height: '60%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('string', 'Month');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last Year');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last Year Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));
  // google.visualization.events.addListener(chart, 'ready', function() {
  //     $("#" + elementId + "_overlay").text("Last updated on " + new Date().toISOString());
  //   // console.log('visible' + $("#chart_real_time_control"));
  // });

  getData(remote_url, chart, data, options, { force: window.forceRefresh == true }, offset);
}

function drawRawChart1(remote_url, elementId, offset) {

  if ($("#" + elementId).length == 0)
    return;

  var t1 = new Date('2015-08-15');
  var t0 = new Date(t1);
  t0.setMonth(t0.getMonth()-1);

  var data = new google.visualization.DataTable();
  var dataCtrl = new google.visualization.DataView(data);
  var dataChart = new google.visualization.DataView(data);
  var dashboard = new google.visualization.Dashboard(document.getElementById('programmatic_dashboard_div'));
  var ctrl = new google.visualization.ControlWrapper({
    'controlType': 'ChartRangeFilter',
    'containerId': 'programmatic_control_div',
    'options': {
      'filterColumnIndex': 0,
      'ui': {
        'chartType': 'LineChart',
        'chartOptions': {
          'chartArea': {'width': '90%'},
          'hAxis': {'baselineColor': 'none'}
        },
        'chartView': dataCtrl,
        'minRangeSize': 86400000
      }
    },
    //'state': {'range': {'start': t0, 'end': t1}}
  });
  var chart = new google.visualization.ChartWrapper({
    'chartType': 'LineChart',
    'containerId': 'programmatic_chart_div',
    'view': dataChart,
    'options': {
      // 'width': 300,
      // 'height': 300,
      'legend': 'none',
      'chartArea': {'left': 15, 'top': 15, 'right': 0, 'bottom': 0}
    }
  });

  var RawChart = {
    'remoteUrl': remote_url,
    'offset': offset,
    'data': data,
    'dataCtrl': dataCtrl,
    'dataChart': dataChart,
    'dashboard': dashboard,
    'ctrl': ctrl,
    'chart': chart,
    'stateLsnr': function(event) {
      s = RawChart.ctrl.getState();
      console.log("XXXX", s.range.start, s.range.end, event);
      if (!event.inProgress)
        RawChart.getData({ force: window.forceRefresh == true, start_p: s.range.start, end_p: s.range.end }, 1);
      else {
        RawChart.dataChart.setRows([]);
        RawChart.chart.draw();
      }

    },
    'init': function() {
      this.data.addColumn('datetime', 'Time');
      this.data.addColumn('number', 'Power');
      this.data.addColumn('number', 'Mode');

      this.dashboard.bind(this.ctrl, this.chart);
      this.dashboard.draw(this.data);

      google.visualization.events.addListener(this.ctrl, 'statechange', this.stateLsnr);

      this.getData({ force: window.forceRefresh == true }, 0);
      //this.getData({ force: window.forceRefresh == true, start_p: t0, end_p: t1 }, 1);
    },
    'getData': function(params, mode) {
      $.ajax({
        type:"get",
        url: this.remoteUrl,
        data: params,
        contentType: "application/json"
      })
      .done(function(json){
        if (json.data.length > 0) {
          if (mode == 1 && RawChart.dataChart.getNumberOfRows() > 0) {
            i = RawChart.dataChart.getTableRowIndex(0);
            RawChart.data.removeRows(i, RawChart.dataChart.getNumberOfRows());
          }
          for(j = 0; j < json.data.length; j++) {
            json.data[j][0] = getDateTZ(json.data[j][0], RawChart.offset);
            json.data[j][2] = mode;
          }
          RawChart.data.addRows(json.data);
          RawChart.dataCtrl.setRows(RawChart.data.getFilteredRows([{column: 2, value: 0}]));
          RawChart.dataChart.setRows(RawChart.data.getFilteredRows([{column: 2, value: 1}]));
          RawChart.ctrl.setState({'range': {'start': t0, 'end': t1}});
          console.log("Request successful!", json, "T=", RawChart.data.getNumberOfRows(), ",T0=", RawChart.dataCtrl.getNumberOfRows(), "T1=", RawChart.dataChart.getNumberOfRows());
          if (mode == 0)
            RawChart.ctrl.draw();
          else
            RawChart.chart.draw();
          // RawChart.dashboard.draw();
        }
      });
    }
  };
  RawChart.init();
  // google.visualization.events.trigger(programmaticSlider, 'statechange', null);
}

var TS = {
  define: function(chartId, sliderId, bound_start, bound_end, def_start, def_end) {
    var monthNames = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];

    this.chart = new google.visualization.ChartWrapper({
      'chartType': 'LineChart',
      'containerId': chartId,
      'options': {
        'title':'Power Usage (Watt)', 
        'legend': 'none'
      }
    });

    $("#" + sliderId).dateRangeSlider({
      bounds: {min: bound_start, max: bound_end},
      defaultValues: {min: def_start, max: def_end},
      scales: [{
        first: function(value){ return value; },
        end: function(value) {return value; },
        next: function(value){
          var next = new Date(value);
          return new Date(next.setMonth(value.getMonth() + 1));
        },
        label: function(value){
          return monthNames[value.getMonth()];
        }
      }]
    });

    $("#" + sliderId).bind("userValuesChanged", function(e, data){
      // console.log(data.values);
      TS.getData(data.values.min, data.values.max);
    });
  },
  getData: function(bound_start, bound_end) {
    var params = { force: window.forceRefresh == true, start_p: bound_start, end_p: bound_end };
    $.ajax({
      type:"get",
      url: TS.remoteUrl,
      data: params,
      contentType: "application/json"
    })
    .done(function(json){
      // console.log("Request successful!", json);
      TS.chart.setDataTable(json);
      TS.chart.draw();
    });
  },
  init: function(chartId, sliderId, remoteUrl, timeIntervalUrl, offset) {
    if ($("#" + chartId + ",#" + sliderId).length != 2)
      return;
    this.remoteUrl = remoteUrl;
    $.ajax({
      type:"get",
      url: timeIntervalUrl,
      contentType: "application/json"
    })
    .done(function(json){
      // console.log("Request successful!", json);
      if (json.time_start == null || json.time_end == null)
        return;
      t_start = getDateTZ(json.time_start, offset);
      t_end = getDateTZ(json.time_end, offset);
      b_end = t_end;
      b_start = new Date(b_end);
      b_start.setMonth(b_start.getMonth() - 1);
      b_start = t_start > b_start ? t_start : b_start;
      // console.log(b_start, b_end);
      TS.define(chartId, sliderId, t_start, t_end, b_start, b_end);
      TS.getData(b_start, b_end);
    });    
  }
}
