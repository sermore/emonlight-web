
function getDateTZ(json, offset) {
  var d = new Date(json);
  var utc = d.getTime() + (d.getTimezoneOffset() * 60000);
  var nd = new Date(utc + (offset*1000));
  return nd;
}

function getData(remoteUrl, chart, options, params, offset) {
  $.ajax({
    type:"get",
    url: remoteUrl,
    data: params,
    contentType: "application/json"
  })
  .done(function(json){
    if (json.data.length > 0) {
      // console.log("Request successful!", json);
      var data = new google.visualization.DataTable(json.data);
      options['title'] += ' - Last update ' + getDateTZ(json.last_update, offset).toLocaleString();
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
    'title':'Real Time Power Usage (W)', 
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},    
    legend: 'none',
    }//,
/*        'width':400,
  'height':300};
  */
  rtFormatter = new google.visualization.NumberFormat({fractionDigits: 2});
  var chart = new google.visualization.LineChart(document.getElementById(elementId));
  window.evLsn = google.visualization.events.addListener(chart, 'ready', function() {
    if (data.getNumberOfRows() > 0)
      $("#chart_real_time_control").removeClass("hidden");
    $("#set-real-time-interval").prop('disabled', false);
    // console.log('visible' + $("#chart_real_time_control"));
    google.visualization.events.removeListener(window.evLsn);
  });

  t = new Date(new Date().getTime() - timeInterval*60000);
  loadRealTimeData(remote_url, chart, data, options, timeInterval, t, elementId, offset);

  if (window.realTimeIntervalId)
    clearInterval(window.realTimeIntervalId);
  window.realTimeIntervalId = setInterval(loadRealTimeData.bind(null, remote_url, chart, data, options, timeInterval, null, elementId, offset), 1000 * 5);
}

function loadRealTimeData(remote_url, chart, data, options, timeInterval, time, elementId, offset) {
  if (window.real_time_callback_pending)
    return;
  if (time == null) {
    time = new Date(new Date().getTime() - 5000);
  }
  timeLimit = new Date(new Date().getTime() - timeInterval*60000);

  var req = $.ajax({
    type:"get",
    url: remote_url,
    data:{ time: time },
    timeout: 25000,
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
      window.rtFormatter.format(data, 1);
      chart.draw(data, options);            
    }
    if ($("#" + elementId).length == 0) {
      clearInterval(window.realTimeIntervalId);
    }
  })
  .always(function() {
    window.real_time_callback_pending = false;
  });
}

function drawWeeklyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Weekly Power Usage (kW/day)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    // ,chartArea: { height: '45%' }
    //,height: 400
  };

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, options, { force: window.forceRefresh == true }, offset);
}

function drawDailyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Daily Power Usage (W/hour)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    //,chartArea: { height: '45%' }
    //,height: 400
  };

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, options, { force: window.forceRefresh == true }, offset);
}

function drawMonthlyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Monthly Power Usage (kW/day)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    //,chartArea: { height: '45%' }
    //,height: 400
  };

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, options, { force: window.forceRefresh == true }, offset);
}

function drawYearlyChart(remote_url, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Yearly Power Usage (kW/month)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    // ,chartArea: { width: '90%', height: '60%' }
    //,height: 400
  };

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));
  // google.visualization.events.addListener(chart, 'ready', function() {
  //     $("#" + elementId + "_overlay").text("Last updated on " + new Date().toISOString());
  //   // console.log('visible' + $("#chart_real_time_control"));
  // });

  getData(remote_url, chart, options, { force: window.forceRefresh == true }, offset);
}

function drawDailyPerMonthChart(remoteUrl, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Daily Mean Power Usage (kW/day)',
    legend: { position: 'bottom' },
    // vAxis: {title: 'Power'},
    // hAxis: {title: 'Time', textPosition: 'out'},
    isStacked: true,
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}, 4: {type: 'line'}}
    // ,chartArea: { width: '90%', height: '60%' }
    //,height: 400
  };
  var chart = new google.visualization.ComboChart(document.getElementById(elementId));
  getData(remoteUrl, chart, options, { force: window.forceRefresh == true }, offset);
}

function drawSlotPercentageChart(remoteUrl, elementId, offset) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Power Usage per Time Slot (%)',
    legend: { position: 'bottom' }
  };
  var chart = new google.visualization.PieChart(document.getElementById(elementId));
  getData(remoteUrl, chart, options, { force: window.forceRefresh == true }, offset);
}

var TS = {
  define: function(chartId, sliderId, bound_start, bound_end, def_start, def_end) {
    var monthNames = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];

    this.chart = new google.visualization.ChartWrapper({
      'chartType': 'LineChart',
      'containerId': chartId,
      'options': {
        'title':'Power Usage (W)', 
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
