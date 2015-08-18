//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require turbolinks
//= require_tree .

var Interval;

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