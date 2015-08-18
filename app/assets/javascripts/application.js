//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require turbolinks
//= require_tree .

var Interval;

function get_info(){
    show_history_calls();
    show_live_calls();
    setStatus();
    setNumberFormat();
}

function show_live_calls(){
    var calling_data = $.ajax({
        type: "get",
        url: "/calling_info_callback",
        async: false,
    }).responseText;
    var obj = JSON.parse(calling_data);
    var out = "<table class='table-responsive table table-striped history-table'>" + 
        "<thead><tr><th>Caller Number</th><th>Name</th><th>Time</th><th>Ringing Number</th><th>Status</th>" + 
        "<th>timer</th></tr></thead>";
    out += "<tbody>";
    $.each(obj, function (key, data) {
        out += "<tr>";
        out += "<td class='number'>" + data.Caller + "</td>";
        out += "<td>" + data.name + "</td>"
        var date = new Date(data.time * 1000);
        out += "<td>" + timeFormat(date) + "</td>";
        out += "<td class='number'>" + data.calling_number + "</td>"
        out += "<td class='status'>" + data.status + "</td>"
        
        if (data.status == "talking" || data.status == "calling center answers"){
            out += "<td>" + startTimer(date) + "</td>";
        }
        else {
            out += "<td>not timing now</td>";
        }
        out += "</tr>";
    });
    out += "</tbody>";
    out += "</table>";
    $('#test').html(out);
}

function show_history_calls(){
    var calling_history_data = $.ajax({
        type: "get",
        url: "/calling_history_callback",
        async: false,
    }).responseText;
    var history_data = JSON.parse(calling_history_data);
    var history = "<table class='table-responsive table table-striped'><thead><tr><th>Caller Number</th><th>Caller Name</th>" + 
        "<th>Calling Time</th><th>Answer Number</th><th>Duartion</th><th>Status</th></tr></thead>";
    history += "<tbody>";    
    if (history_data != null){
        for (var i=0; i<history_data.length; i++){
            history += "<tr>";
            history += "<td class='number'>" + history_data[i].inbound_number + "</td>";
            history += "<td>" + history_data[i].caller_name + "</td>";
            var date = new Date(history_data[i].calling_time * 1000);
            history += "<td>" + timeFormat(date) + "</td>";
            history += "<td class='number'>" + history_data[i].answer_number + "</td>";
            history += "<td>" + secondsToHms(history_data[i].duration) + "</td>";
            history += "<td class='status'>" + history_data[i].status + "</td>";
            history += "</tr>";
        }
    }
    history += "</tbody>";  
    history += "</table>";
    $('#history').html(history);
}

function startTimer(date) {
    var now = new Date();
    var sec = parseInt(now.getTime() - date.getTime())/1000 - 5*3600;
    if (sec >= 0 ){
        return secondsToHms(sec);
    }
    else {
        return 0;
    }
}

function secondsToHms(d) {
    d = Number(d);
    var h = Math.floor(d / 3600);
    var m = Math.floor(d % 3600 / 60);
    var s = Math.floor(d % 3600 % 60);
    return ((h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (s < 10 ? "0" : "") + s); 
}

function timeFormat(date){
    var d = date.getFullYear();
    d += "-" + (date.getMonth() + 1 < 10 ? "0" : "") + (date.getMonth() + 1);
    d += "-" + (date.getDate() < 10 ? "0" : "") + date.getDate();
    d += " " + ( (date.getHours() + 5) < 10 ? "0" : "") + (date.getHours() + 5) + ":";
    d += " " + (date.getMinutes()< 10 ? "0" : "") + date.getMinutes() + ":";
    d += " " + (date.getSeconds() < 10 ? "0" : "") + date.getSeconds();
    return d.toString();
}

function phoneNumberFormat(number){
    if(number.charAt(0) == '+' && number.length == 12){
        var n = "(" + number.substring(2,5) + ") " + number.substring(5,8) + "-" + number.substring(8,12);
        return n.toString();
    }
    else {
        return number;
    }
}

function setNumberFormat(){
    var x = document.getElementsByClassName("number");
    for (var i = 0; i < x.length ; i++){
        if (x[i].childNodes[0] != null){
            x[i].childNodes[0].nodeValue = phoneNumberFormat(x[i].childNodes[0].nodeValue);
        }
    }
    
    var y = document.getElementsByClassName("time");
    for (var i = 0; i < y.length ; i++){
        var date = new Date(y[i].childNodes[0].nodeValue * 1000);
        y[i].childNodes[0].nodeValue = timeFormat(date);
    }    
}

function regularDate(){
    $( ".datepicker" ).datepicker({
        dateFormat : 'mm-dd-yy',
        beforeShowDay : function (date){
            var d = new Date();
            if (date > new Date()){
                return [false];
            }
            else {
                return [true];
            }
        }
    });
}

function setStatus() {
    var x = document.getElementsByClassName("status");
    for (var i = 0; i < x.length ; i++){
        if(x[i].innerHTML == "finish talking"){
            x[i].parentElement.classList.add("success");
        }
        else if(x[i].innerHTML == "hang up by caller"){
            x[i].parentElement.classList.add("danger");
        }
        else {
            x[i].parentElement.classList.add("warning");
        }
    }
}