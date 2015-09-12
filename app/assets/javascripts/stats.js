
function getData(remote_url, chart, data, options) {
  $.ajax({
    type:"get",
    url: remote_url,
    contentType: "application/json"
  })
  .done(function(json){
    if (json.length > 0) {
      console.log("Request successful!", json);
      data.addRows(json);
      chart.draw(data, options);
    }
  });
}

function drawRealTimeChart(remote_url, elementId, timeInterval, offset) {

  if ($("#" + elementId).length == 0)
    return;

  // Create the data table.
  var data = new google.visualization.DataTable();
  data.addColumn('datetime', 'Time');
  data.addColumn('number', 'Power');

  // Set chart options
  var options = {
    'title':'Real Time Power Usage (Watt)', 
    vAxis: {title: 'Power'},
    hAxis: {title: 'Time', textPosition: 'out'},    
    legend: 'none',
    }//,
/*        'width':400,
  'height':300};
  */
  // Instantiate and draw our chart, passing in some options.
  var chart = new google.visualization.LineChart(document.getElementById(elementId));
  t = new Date();
  t.setMinutes(t.getMinutes() - timeInterval);
  loadRealTimeData(remote_url, chart, data, options, timeInterval, t, elementId, offset);

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
        d = new Date(json[j][0]);
        utc = d.getTime() + (d.getTimezoneOffset() * 60000);
        nd = new Date(utc + (offset*1000));
        json[j][0] = nd;
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

function drawWeeklyChart(remote_url, elementId) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Weekly Power Usage (Watt/day)',
    legend: { position: 'bottom' },
    vAxis: {title: 'Power'},
    hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    ,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('string', 'Day of the week');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last 7 days');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last 7 days Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options);
}

function drawDailyChart(remote_url, elementId) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Daily Power Usage (Watt/hour)',
    legend: { position: 'bottom' },
    vAxis: {title: 'Power'},
    hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    ,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('number', 'Hour');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last Day');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last Day Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options);
}

function drawMonthlyChart(remote_url, elementId) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Monthly Power Usage (Watt/day)',
    legend: { position: 'bottom' },
    vAxis: {title: 'Power'},
    hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    ,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('number', 'Day');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last Day');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last Day Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options);
}


function drawYearlyChart(remote_url, elementId) {
  if ($("#" + elementId).length == 0)
    return;

  var options = {
    title : 'Yearly Power Usage (Watt/month)',
    legend: { position: 'bottom' },
    vAxis: {title: 'Power'},
    hAxis: {title: 'Time', textPosition: 'out'},
    seriesType: 'bars',
    series: {2: {type: 'line'}, 3: {type: 'line'}}
    ,chartArea: { height: '45%' }
    //,height: 400
  };

  var data = new google.visualization.DataTable();
  data.addColumn('string', 'Month');
  data.addColumn('number', 'Overall');
  data.addColumn('number', 'Last Day');
  data.addColumn('number', 'Overall Mean');
  data.addColumn('number', 'Last Day Mean');

  var chart = new google.visualization.ComboChart(document.getElementById(elementId));

  getData(remote_url, chart, data, options);
}
